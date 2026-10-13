module Hermes
  class PromptBuilder
    BASE_FORMAT_HINT = "For formatting do not use markup, you must use HTML tags like <ul>,<li>,<a>,<b>,<pre>, specially for codes use <pre> tag".freeze
    BASE_KANBAN_BOARD = "use anban board per room, if room is not created yesm create one, this would be used for collaboration".freeze
    BASE_RESPONSE = "This message is sent from specific room send response to that room use agent with the same name of bot for sending message. ".freeze
    BASE_SYSTEM_PROMPT = "#{BASE_RESPONSE} \n #{BASE_FORMAT_HINT} \n #{BASE_KANBAN_BOARD}".freeze

    def self.base_system_prompt
      BASE_SYSTEM_PROMPT
    end

    def self.build_space_event_message(event_type, event_data)
      data = (event_data || {}).deep_stringify_keys
      serialized = data.to_json

      if event_type.present?
        "New W-space event\n(#{event_type}): #{serialized}"
      else
        "New W-space event\n#{serialized}"
      end
    end

    def self.build_attachment_summary(attachments)
      return "" if attachments.blank?

      lines = ["", "Attachments:"]
      Array(attachments).each_with_index do |att, idx|
        filename = att[:filename] || att["filename"] || "attachment"
        mime_type = att[:mime_type] || att["mime_type"] || "application/octet-stream"
        url = att[:url] || att["url"]
        if url.present?
          lines << "#{idx + 1}. #{filename} (#{mime_type}) -> #{url}"
        else
          msg_id = att[:message_id] || att["message_id"] || "unknown"
          room_id = att[:room_id] || att["room_id"] || "unknown"
          lines << "#{idx + 1}. #{filename} (#{mime_type}) -> message_id=#{msg_id}, room_id=#{room_id}"
        end
      end
      lines.join("\n")
    end

    def self.build_chat_payload(event_type, event_data, unresolved_attachments: [], model: nil)
      message_content = build_space_event_message(event_type, event_data)
      if unresolved_attachments.any?
        message_content = "#{message_content}\n#{build_attachment_summary(unresolved_attachments)}"
      end

      payload = {
        messages: [
          {
            role: "user",
            content: message_content
          }
        ]
      }
      payload[:model] = model if model.present?
      payload
    end

    def self.extract_reply_text(payload)
      return "" unless payload.is_a?(Hash)

      choices = payload["choices"] || payload[:choices]
      return "" unless choices.is_a?(Array) && choices.any?

      first_choice = choices.first
      return "" unless first_choice.is_a?(Hash)

      message = first_choice["message"] || first_choice[:message]
      return "" unless message.is_a?(Hash)

      content = message["content"] || message[:content]
      content.is_a?(String) ? content : ""
    end
  end
end
