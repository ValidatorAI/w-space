module OutputEvents
  class PayloadMerger
    PAYLOAD_PRIORITY = {
      "message_attachment_uploaded" => 1,
      "message_created" => 2,
      "ai_question_asked" => 3
    }.freeze

    # Merges an array of OutputEvent records belonging to the same dispatch unit
    # Returns [merged_event_type, merged_event_data]
    def self.merge(events)
      return [nil, {}] if events.blank?

      events_list = Array(events).compact
      return [events_list.first.event_type, events_list.first.event_data] if events_list.size == 1

      # Sort from lowest priority to highest priority so higher overlays lower
      sorted_events = events_list.sort_by do |ev|
        PAYLOAD_PRIORITY.fetch(ev.event_type.to_s, 0)
      end

      merged_type = sorted_events.last.event_type
      # If any member is an ai_question_asked, lock merged type to ai_question_asked
      if sorted_events.any? { |ev| ev.event_type.to_s == "ai_question_asked" }
        merged_type = "ai_question_asked"
      end

      merged_data = {}
      sorted_events.each do |ev|
        data = (ev.event_data || {}).deep_stringify_keys
        merged_data = deep_merge(merged_data, data)
      end

      [merged_type, merged_data]
    end

    def self.deep_merge(target, source)
      result = target.dup

      source.each do |key, source_val|
        target_val = result[key]

        if target_val.is_a?(Hash) && source_val.is_a?(Hash)
          result[key] = deep_merge(target_val, source_val)
        elsif target_val.is_a?(Array) && source_val.is_a?(Array)
          result[key] = (target_val + source_val).uniq
        elsif !source_val.nil?
          result[key] = source_val
        end
      end

      result
    end
    private_class_method :deep_merge
  end
end
