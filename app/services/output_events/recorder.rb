module OutputEvents
  class Recorder
    FILTERED_EVENT_TYPES = %w[
      typing_start
      typing_stop
      account_settings_updated
      account_bot_access_updated
      bot_created
      bot_updated
      bot_deleted
      user_activated
      user_deactivated
      user_banned
      user_unbanned
      room_created
      room_updated
      room_deleted
      room_member_added
      room_member_removed
      room_involvement_changed
      room_privacy_changed
      room_archived
      room_unarchived
      direct_conversation_created
      project_deleted
      project_archived
      project_unarchived
      project_member_added
      project_member_removed
      project_first_joined
      ai_config_reset
    ].freeze

    def self.record(event_type:, event_id: nil, group_id: nil, actor: nil, target_type: nil, data: {})
      return if filtered_event_type?(event_type)

      payload_data = (data || {}).deep_stringify_keys
      normalized_content = ContentBuilder.build(
        event_type: event_type,
        event_id: event_id,
        target_type: target_type,
        data: payload_data
      )
      knowledge_path = KnowledgePathResolver.resolve(
        event_type: event_type,
        event_id: event_id,
        target_type: target_type,
        data: payload_data
      )

      event_data = payload_data.except("content", "content_payload").merge(
        "actor" => actor_data(actor),
        "target_type" => target_type,
        "occurred_at" => Time.current.iso8601
      ).compact
      event_data["content"] = normalized_content["content"]
      event_data["content_payload"] = normalized_content["content_payload"]
      event_data["knowledge_path"] = knowledge_path if knowledge_path.present?

      event = OutputEvent.create!(
        event_type: event_type,
        event_id: event_id,
        group_id: group_id,
        event_data: event_data
      )

      ProcessAndDispatchJob.perform_later(event.id)
      DeliverJob.perform_later(event.id) if ENV["OUTPUT_EVENTS_URL"].present?
      event
    end

    def self.actor_data(actor)
      return unless actor

      {
        "type" => actor.class.name,
        "id" => actor.id,
        "username" => (actor.name if actor.respond_to?(:name)),
        "full_name" => (
          if actor.respond_to?(:effective_display_name)
            actor.effective_display_name
          elsif actor.respond_to?(:name)
            actor.name
          end
        )
      }.compact
    end
    private_class_method :actor_data

    def self.filtered_event_type?(event_type)
      FILTERED_EVENT_TYPES.include?(event_type.to_s)
    end
    private_class_method :filtered_event_type?
  end
end