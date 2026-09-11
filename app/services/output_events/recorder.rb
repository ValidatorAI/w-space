module OutputEvents
  class Recorder
    FILTERED_EVENT_TYPES = %w[typing_start typing_stop].freeze

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

      DeliverJob.perform_later(event.id)
      event
    end

    def self.actor_data(actor)
      return unless actor

      {
        "type" => actor.class.name,
        "id" => actor.id,
        "username" => (actor.name if actor.respond_to?(:name))
      }.compact
    end
    private_class_method :actor_data

    def self.filtered_event_type?(event_type)
      FILTERED_EVENT_TYPES.include?(event_type.to_s)
    end
    private_class_method :filtered_event_type?
  end
end