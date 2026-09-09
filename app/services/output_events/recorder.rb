module OutputEvents
  class Recorder
    def self.record(event_type:, event_id: nil, group_id: nil, actor: nil, target_type: nil, data: {})
      payload_data = (data || {}).deep_stringify_keys
      knowledge_path = KnowledgePathResolver.resolve(
        event_type: event_type,
        event_id: event_id,
        target_type: target_type,
        data: payload_data
      )

      event_data = payload_data.merge(
        "actor" => actor_data(actor),
        "target_type" => target_type,
        "occurred_at" => Time.current.iso8601
      ).compact
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

      { "type" => actor.class.name, "id" => actor.id }
    end
    private_class_method :actor_data
  end
end