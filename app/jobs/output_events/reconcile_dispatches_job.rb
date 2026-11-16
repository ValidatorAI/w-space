module OutputEvents
  class ReconcileDispatchesJob < ApplicationJob
    queue_as :default

    DEFAULT_LOOKBACK = 15.minutes
    MIN_STALE_AGE = 30.seconds
    ORPHAN_BATCH_SIZE = 50

    def perform(max_age: nil)
      lookback_window = (max_age || Hermes.configuration.event_recovery_max_age_seconds.seconds)
      cutoff = Time.current - lookback_window
      stale_threshold = Time.current - MIN_STALE_AGE

      hermes_client = Hermes::Client.new
      hermes_status = begin
        hermes_client.api_status_summary
      rescue Exception => e
        Rails.logger.warn("[OutputEvents::ReconcileDispatchesJob] Hermes status check failed: #{e.class.name}: #{e.message}")
        { "active_agents" => Hermes.configuration.max_active_agents, "gateway_busy" => true, "overall" => "unavailable" }
      end
      Rails.logger.info("[OutputEvents::ReconcileDispatchesJob] Hermes status: #{hermes_status.to_json}")

      max_active_agents = Hermes.configuration.max_active_agents
      active_agents = hermes_status["active_agents"].to_i
      if active_agents >= max_active_agents && max_active_agents > 0
        Rails.logger.warn("[OutputEvents::ReconcileDispatchesJob] Skipping dispatch reconciliation: active_agents=#{active_agents} >= threshold=#{max_active_agents}")
        return { reconciled_count: 0, throttled: true, hermes_status: hermes_status, orphan_requeued_count: 0 }
      end

      stale_groups = OutputEventDispatchGroup
        .where(status: %w[pending deferred_merge_window dispatching])
        .where("created_at >= ? AND created_at <= ?", cutoff, stale_threshold)
        .order(:created_at)

      reconciled = []
      stale_groups.each do |group|
        if group.status == "dispatching"
          result = parse_group_result(group)
          scheduled_at = result["scheduled_at"].presence
          next if scheduled_at.blank?

          begin
            next if Time.iso8601(scheduled_at) > Time.current - 5.seconds
          rescue ArgumentError
            next
          end
        end

        result = parse_group_result(group)
        queued_at = result["dispatch_queued_at"].presence
        if queued_at.present?
          begin
            next if Time.iso8601(queued_at) > 5.seconds.ago
          rescue ArgumentError
            # malformed timestamp should still allow a fresh retry once
          end
        end

        result["dispatch_queued_at"] = Time.current.iso8601
        group.update!(status: "pending", result: result.to_json)

        lead_event = OutputEvent.find_by(id: group.lead_output_event_id) if group.lead_output_event_id.present?
        lead_event ||= recover_lead_event_for_group(group)
        if lead_event.present?
          ProcessAndDispatchJob.perform_later(lead_event.id, stage: :dispatch, dispatch_group_id: group.id)
          reconciled << group.id
        end
      end

      orphan_requeued_ids = recover_orphans(cutoff, limit: ORPHAN_BATCH_SIZE)

      expired_count = 0
      OutputEventDispatchGroup
        .where(status: %w[pending deferred_merge_window dispatching])
        .where("created_at < ?", cutoff)
        .find_each do |group|
          group.update!(
            status: "failed",
            result: { error: "Reconciliation expired: exceeded lookback of #{lookback_window.to_i} seconds" }.to_json
          )
          expired_count += 1
        end

      Rails.logger.info("[OutputEvents::ReconcileDispatchesJob] Reconciled #{reconciled.size} group(s), orphaned #{orphan_requeued_ids.size} event(s), expired #{expired_count} group(s)")
      {
        reconciled_count: reconciled.size,
        reconciled_group_ids: reconciled,
        orphan_requeued_count: orphan_requeued_ids.size,
        orphan_requeued_ids: orphan_requeued_ids,
        expired_count: expired_count,
        hermes_status: hermes_status
      }
    end

    private

    def recover_orphans(_cutoff, limit: ORPHAN_BATCH_SIZE)
      OutputEvent
        .where(synced: false)
        .where("created_at <= ?", Time.current - MIN_STALE_AGE)
        .where("updated_at <= ?", Time.current - MIN_STALE_AGE)
        .order(:created_at, :id)
        .limit(limit)
        .filter_map do |event|
          next if dispatch_group_references_event?(event)

          event.touch(:updated_at)
          ProcessAndDispatchJob.perform_later(event.id)
          event.id
        end
    end

    def dispatch_group_references_event?(event)
      return false if event.blank?
      return true if OutputEventDispatchGroup.exists?(lead_output_event_id: event.id)
      return false if event.group_id.blank?

      OutputEventDispatchGroup.where("dedupe_key LIKE ?", "%#{event.group_id}%").exists?
    end

    def parse_group_result(group)
      return {} if group.blank? || group.result.blank?

      JSON.parse(group.result)
    rescue JSON::ParserError
      {}
    end

    def recover_lead_event_for_group(group)
      return if group.blank?

      dedupe_key = group.dedupe_key.to_s
      group_id = if dedupe_key.start_with?("message:")
        dedupe_key.split(":", 3)[1]
      else
        dedupe_key
      end
      return if group_id.blank?

      OutputEvent.where(group_id: group_id).where(synced: false).order(:id).first ||
        OutputEvent.where(group_id: group_id).order(:id).first
    end
  end
end
