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
        ProcessAndDispatchJob.set(wait: Deduplicator.settle_delay).perform_later(
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

      # Resolve attachments directly from ActiveStorage / event payload
      files, unresolved = Hermes::AttachmentResolver.resolve(merged_data)

      # Build Hermes chat completions payload
      chat_payload = Hermes::PromptBuilder.build_chat_payload(
        merged_type,
        merged_data,
        unresolved_attachments: unresolved
      )

      # Determine target profile based on event type and configured env overrides
      target_profile = resolve_profile(merged_type, merged_data)

      # Check Hermes gateway concurrency throttle before dispatching
      hermes_client = Hermes::Client.new
      max_active_agents = Hermes.configuration.max_active_agents
      if max_active_agents.positive?
        hermes_status = begin
          hermes_client.api_status_summary
        rescue Exception => e
          Rails.logger.warn("[OutputEvents::ProcessAndDispatchJob] Hermes status check failed: #{e.class.name}: #{e.message}")
          { "active_agents" => max_active_agents, "gateway_busy" => true, "overall" => "unavailable" }
        end

        active_agents = hermes_status["active_agents"]
        if active_agents.nil? || active_agents.to_i >= max_active_agents
          retry_meta = begin
            group.result.present? ? JSON.parse(group.result) : {}
          rescue JSON::ParserError
            {}
          end

          if retry_meta.is_a?(Hash) && retry_meta["retry_reason"] == "hermes_busy"
            Rails.logger.warn("[OutputEvents::ProcessAndDispatchJob] Hermes busy or unavailable and retry already queued for group #{group.id}; skipping duplicate reschedule.")
            return
          end

          Rails.logger.warn("[OutputEvents::ProcessAndDispatchJob] Hermes busy or unavailable (active_agents=#{active_agents.inspect} >= threshold=#{max_active_agents}). Rescheduling group #{group.id}.")
          group.update!(status: "pending", result: { retry_reason: "hermes_busy", scheduled_at: Time.current.iso8601 }.to_json)
          ProcessAndDispatchJob.set(wait: 5.seconds).perform_later(
            lead_event.id,
            stage: :dispatch,
            dispatch_group_id: group.id
          )
          return
        end
      end

      # Dispatch to Hermes
      hermes_response = nil
      begin
        hermes_response = hermes_client.chat_completions(
          chat_payload,
          profile: target_profile,
          files: files.presence
        )
      rescue StandardError => e
        Rails.logger.error("[OutputEvents::ProcessAndDispatchJob] Hermes dispatch failed: #{e.class.name}: #{e.message}")
        group.update!(
          status: "failed",
          result: { error: e.message, backtrace: e.backtrace&.first(10) }.to_json
        )
        return
      end

      # Record success and update dispatch group
      group.update!(
        status: "dispatched",
        dispatched_at: Time.current,
        result: {
          event_type: merged_type,
          profile: target_profile,
          merged_members: sibling_events.map(&:id),
          response: hermes_response,
          event_data_summary: merged_data.slice("target_type", "occurred_at", "content", "bot_user_ids")
        }.to_json
      )

      # Mark all member events as synced
      sibling_events.each do |ev|
        ev.update(synced: true) unless ev.synced?
      end

      Rails.logger.info("[OutputEvents::ProcessAndDispatchJob] Successfully dispatched group #{group.id} (key: #{group.dedupe_key}) to Hermes profile #{target_profile}")
    end

    def resolve_profile(event_type, event_data)
      configured_profile = if ai_settings_profile_event?(event_type)
        ENV["OUTPUT_AI_SETTING_PROFILE"].presence || ENV["HERMES_DEFAULT_PROFILE"].presence || Hermes.configuration.default_profile
      elsif workspace_profile_event?(event_type)
        ENV["OUTPUT_WORKSPACE_PROFILE"].presence || ENV["HERMES_DEFAULT_PROFILE"].presence || Hermes.configuration.default_profile
      else
        ENV["OUTPUT_MESSAGE_PROFILE"].presence || ENV["HERMES_DEFAULT_PROFILE"].presence || Hermes.configuration.default_profile
      end

      return configured_profile if configured_profile.present?

      # If bot users were targeted, check if any has an AiProfile with matching bot_name
      bot_ids = Array(event_data["bot_user_ids"]).compact
      if bot_ids.any?
        bot_user = User.bot.find_by(id: bot_ids.first)
        if bot_user.present?
          profile = AiProfile.where(bot: true).find_by(bot_name: bot_user.name) ||
                    AiProfile.where(bot: true).find_by(profile_name: bot_user.name)
          return profile.profile_name if profile&.profile_name.present?
        end
      end

      Hermes.configuration.default_profile
    end

    def ai_settings_profile_event?(event_type)
      return false if event_type.blank?

      event_type.to_s.start_with?("ai_setting_", "ai_profile_", "mcp_", "skill_", "ai_config_")
    end

    def workspace_profile_event?(event_type)
      return false if event_type.blank?

      event_type.to_s.start_with?(
        "project_created",
        "project_updated",
        "all_hands_action_item_completed",
        "all_hands_action_item_reopened",
        "project_todo_completed",
        "project_todo_reopened"
      )
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
