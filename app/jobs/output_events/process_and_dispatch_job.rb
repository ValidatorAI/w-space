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
        group = claim_result.group
        Rails.logger.info("[OutputEvents::Deduplicator] Event #{event.id} is duplicate member of group #{group&.id} (key: #{claim_result.dedupe_key})")
        event.update_columns(synced: false) if event.synced?

        if recoverable_duplicate_group?(group)
          enqueue_duplicate_recovery(event, group)
        end
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

      if group.status == "dispatching" && !dispatch_token_stale?(group)
        return
      end

      dispatch_lead_event = lead_event.presence || recover_lead_event_for_group(group)
      return if dispatch_lead_event.blank?

      if group.lead_output_event_id.blank?
        group.update!(lead_output_event_id: dispatch_lead_event.id)
      end

      sibling_events = resolve_group_events(group, dispatch_lead_event)
      sibling_events.each { |ev| ev.update_columns(synced: false) }

      group.update!(status: "dispatching")

      merged_type, merged_data = PayloadMerger.merge(sibling_events)
      files, unresolved = Hermes::AttachmentResolver.resolve(merged_data)

      chat_payload = Hermes::PromptBuilder.build_chat_payload(
        merged_type,
        merged_data,
        unresolved_attachments: unresolved
      )

      target_profile = resolve_profile(merged_type, merged_data)
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
            scheduled_at = retry_meta["scheduled_at"]
            scheduled_time = nil
            if scheduled_at.present?
              begin
                scheduled_time = Time.iso8601(scheduled_at)
              rescue ArgumentError
                scheduled_time = nil
              end
            end

            if scheduled_time && scheduled_time > 30.seconds.ago
              Rails.logger.warn("[OutputEvents::ProcessAndDispatchJob] Hermes busy or unavailable and retry already queued for group #{group.id}; skipping duplicate reschedule.")
              return
            end
          end

          retry_wait = ENV.fetch("OUTPUT_EVENTS_RETRY_DELAY_SECONDS", "60").to_i
          retry_wait = 60 if retry_wait <= 0

          Rails.logger.warn("[OutputEvents::ProcessAndDispatchJob] Hermes busy or unavailable (active_agents=#{active_agents.inspect} >= threshold=#{max_active_agents}). Rescheduling group #{group.id}.")
          group.update!(status: "pending", result: { retry_reason: "hermes_busy", scheduled_at: Time.current.iso8601, retry_token: SecureRandom.uuid }.to_json)
          OutputEvents::ProcessAndDispatchJob.set(wait: retry_wait.seconds).perform_later(
            lead_event.id,
            stage: :dispatch,
            dispatch_group_id: group.id
          )
          return
        end
      end

      hermes_response = nil
      begin
        hermes_response = hermes_client.chat_completions(
          chat_payload,
          profile: target_profile,
          files: files.presence
        )
      rescue Hermes::Client::HttpError => e
        Rails.logger.error("[OutputEvents::ProcessAndDispatchJob] Hermes dispatch failed: #{e.class.name}: #{e.message}")

        sibling_events.each { |ev| ev.update_columns(synced: false) }

        if e.status_code.to_i == 401
          group.update!(
            status: "failed",
            result: { error: e.message, status_code: e.status_code, backtrace: e.backtrace&.first(10) }.to_json
          )
          return
        end

        group.update!(
          status: "pending",
          result: { error: e.message, status_code: e.status_code, retry_reason: "transient", backtrace: e.backtrace&.first(10), scheduled_at: Time.current.iso8601 }.to_json
        )
        ProcessAndDispatchJob.set(wait: 5.seconds).perform_later(
          lead_event.id,
          stage: :dispatch,
          dispatch_group_id: group.id
        )
        return
      rescue Net::ReadTimeout, Net::OpenTimeout, Faraday::TimeoutError, Timeout::Error => e
        Rails.logger.error("[OutputEvents::ProcessAndDispatchJob] Hermes dispatch timed out: #{e.class.name}: #{e.message}")

        sibling_events.each { |ev| ev.update_columns(synced: false) }

        group.update!(
          status: "pending",
          result: { error: e.message, retry_reason: "transient_timeout", backtrace: e.backtrace&.first(10), scheduled_at: Time.current.iso8601 }.to_json
        )
        ProcessAndDispatchJob.set(wait: 5.seconds).perform_later(
          lead_event.id,
          stage: :dispatch,
          dispatch_group_id: group.id
        )
        return
      rescue StandardError => e
        Rails.logger.error("[OutputEvents::ProcessAndDispatchJob] Hermes dispatch failed: #{e.class.name}: #{e.message}")

        sibling_events.each { |ev| ev.update_columns(synced: false) }

        group.update!(
          status: "pending",
          result: { error: e.message, retry_reason: "transient", backtrace: e.backtrace&.first(10), scheduled_at: Time.current.iso8601 }.to_json
        )
        ProcessAndDispatchJob.set(wait: 5.seconds).perform_later(
          lead_event.id,
          stage: :dispatch,
          dispatch_group_id: group.id
        )
        return
      end

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

      sibling_events.each do |ev|
        ev.update_columns(synced: true)
      end

      Rails.logger.info("[OutputEvents::ProcessAndDispatchJob] Successfully dispatched group #{group.id} (key: #{group.dedupe_key}) to Hermes profile #{target_profile}")
    end

    def recoverable_duplicate_group?(group)
      return false if group.blank?
      return true if group.status == "failed"
      return false if group.status == "dispatched"
      return false unless %w[pending dispatching].include?(group.status.to_s)

      result = parse_group_result(group)
      queued_at = result["dispatch_queued_at"].presence || result["scheduled_at"].presence
      return true if queued_at.blank?

      begin
        queued_time = Time.iso8601(queued_at)
      rescue ArgumentError
        return true
      end

      queued_time <= Time.current - retry_delay_seconds.seconds
    end

    def enqueue_duplicate_recovery(event, group)
      return if group.blank?

      result = parse_group_result(group)
      queued_at = result["dispatch_queued_at"].presence
      if queued_at.present?
        begin
          return if Time.iso8601(queued_at) > 5.seconds.ago
        rescue ArgumentError
          # malformed timestamp should still allow a fresh retry once
        end
      end

      result["dispatch_queued_at"] = Time.current.iso8601
      group.update!(status: "pending", result: result.to_json)
      OutputEvents::ProcessAndDispatchJob.set(wait: 5.seconds).perform_later(
        event.id,
        stage: :dispatch,
        dispatch_group_id: group.id
      )
    end

    def parse_group_result(group)
      return {} if group.blank? || group.result.blank?

      JSON.parse(group.result)
    rescue JSON::ParserError
      {}
    end

    def retry_delay_seconds
      delay = ENV.fetch("OUTPUT_EVENTS_RETRY_DELAY_SECONDS", "60").to_i
      delay.positive? ? delay : 60
    end

    def dispatch_token_stale?(group)
      result = parse_group_result(group)
      scheduled_at = result["dispatch_queued_at"].presence || result["scheduled_at"].presence
      return true if scheduled_at.blank?

      begin
        Time.iso8601(scheduled_at) <= Time.current - 5.seconds
      rescue ArgumentError
        true
      end
    end

    def recover_lead_event_for_group(group)
      return if group.blank?

      lead_event = OutputEvent.find_by(id: group.lead_output_event_id) if group.lead_output_event_id.present?
      return lead_event if lead_event.present?

      group_id = if group.dedupe_key.to_s.start_with?("message:")
        group.dedupe_key.split(":", 3)[1]
      else
        group.dedupe_key.to_s
      end
      return if group_id.blank?

      OutputEvent.where(group_id: group_id).where(synced: false).order(:id).first ||
        OutputEvent.where(group_id: group_id).order(:id).first
    end

    def resolve_profile(event_type, event_data)
      configured_profile = if ai_settings_profile_event?(event_type)
        ENV["OUTPUT_AI_SETTING_PROFILE"].presence || ENV["HERMES_DEFAULT_PROFILE"].presence || Hermes.configuration.default_profile
      elsif workspace_profile_event?(event_type, event_data)
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

    def workspace_profile_event?(event_type, event_data = {})
      return false if event_type.blank?

      target_type = event_data["target_type"].to_s
      return true if %w[AttentionItem CompanyStatusItem].include?(target_type)

      event_type.to_s.start_with?(
        "project_created",
        "project_updated",
        "all_hands_action_item_completed",
        "all_hands_action_item_reopened",
        "project_todo_completed",
        "project_todo_reopened",
        "decision_waiting_",
        "blocker_",
        "outcome_review_",
        "mention_",
        "material_change_",
        "ai_confirm_",
        "knowledge_proposal_",
        "priority_",
        "progress_",
        "risk_",
        "dependency_",
        "change_",
        "learning_",
        "attention_item_"
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
