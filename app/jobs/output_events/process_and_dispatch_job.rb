module OutputEvents
  class ProcessAndDispatchJob < ApplicationJob
    queue_as :default

    # stage: :claim (default on first enqueue) or :dispatch (after settle window)
    def perform(output_event_id, stage: :claim, dispatch_group_id: nil)
      event = OutputEvent.find_by(id: output_event_id)
      return if event.blank?

      if stage.to_sym == :claim
        handle_claim(event)
      elsif stage.to_sym == :dispatch
        handle_dispatch(event, dispatch_group_id: dispatch_group_id)
      end
    end

    private

    def handle_claim(event)
      claim_result = Deduplicator.claim(event)

      if claim_result.duplicate?
        Rails.logger.info("[OutputEvents::Deduplicator] Event #{event.id} is duplicate member of group #{claim_result.group&.id} (key: #{claim_result.dedupe_key})")
        event.update(synced: true) rescue nil
        return
      end

      group = claim_result.group
      key = claim_result.dedupe_key

      if Deduplicator.key_needs_settle?(key)
        # Reschedule execution with settle delay to allow sibling deliveries to settle
        group.update!(status: "deferred_merge_window")
        ProcessAndDispatchJob.set(wait: Deduplicator::SETTLE_DELAY).perform_later(
          event.id,
          stage: :dispatch,
          dispatch_group_id: group.id
        )
      else
        # Single events dispatch immediately
        handle_dispatch(event, dispatch_group_id: group.id)
      end
    end

    def handle_dispatch(lead_event, dispatch_group_id:)
      group = OutputEventDispatchGroup.find_by(id: dispatch_group_id)
      return if group.blank? || group.status == "dispatched"

      # Resolve all sibling events belonging to this dedupe unit
      sibling_events = resolve_group_events(group, lead_event)
      merged_type, merged_data = PayloadMerger.merge(sibling_events)

      # In Phase 4, we perform the merge and record the dispatch.
      # When Hermes client is ready in Phase 5, this triggers the LLM completion call.
      group.update!(
        status: "dispatched",
        dispatched_at: Time.current,
        result: {
          event_type: merged_type,
          merged_members: sibling_events.map(&:id),
          event_data_summary: merged_data.slice("target_type", "occurred_at", "content", "bot_user_ids")
        }.to_json
      )

      # Mark all member events as synced
      sibling_events.each do |ev|
        ev.update(synced: true) unless ev.synced?
      end

      Rails.logger.info("[OutputEvents::ProcessAndDispatchJob] Successfully dispatched group #{group.id} (key: #{group.dedupe_key}) with #{sibling_events.size} member(s)")
    end

    def resolve_group_events(group, lead_event)
      if group.dedupe_key.to_s.start_with?("message:")
        parts = group.dedupe_key.split(":")
        group_id = parts[1]
        events = OutputEvent.where(group_id: group_id).to_a
        events.any? ? events : [lead_event]
      else
        [lead_event]
      end
    end
  end
end
