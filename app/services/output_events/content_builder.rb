module OutputEvents
  class ContentBuilder
    def self.build(event_type:, event_id:, target_type:, data:)
      payload_data = (data || {}).deep_stringify_keys
      explicit_content = payload_data["content"] if payload_data.key?("content")
      explicit_content_payload = payload_data["content_payload"] if payload_data.key?("content_payload")

      return {
        "content" => explicit_content,
        "content_payload" => explicit_content_payload
      } if payload_data.key?("content") || payload_data.key?("content_payload")

      case target_type
      when "Message"
        build_message_content(event_type: event_type, event_id: event_id, data: payload_data)
      when "ApprovalRequest"
        build_approval_request_content(event_id: event_id, data: payload_data)
      when "AttentionItem"
        build_attention_item_content(event_id: event_id, data: payload_data)
      else
        { "content" => nil, "content_payload" => nil }
      end
    end

    def self.build_message_content(event_type:, event_id:, data:)
      message = Message.find_by(id: event_id)
      content = message&.plain_text_body&.presence

      if event_type.to_s == "message_attachment_uploaded"
        return {
          "content" => content || data["filename"],
          "content_payload" => {
            "type" => "file",
            "message_id" => event_id,
            "room_id" => data["room_id"],
            "file" => attachment_payload(message)
          }.compact
        }
      end

      {
        "content" => content,
        "content_payload" => {
          "type" => "message",
          "message_id" => event_id,
          "room_id" => data["room_id"],
          "content_type" => data["content_type"] || message&.content_type&.to_s,
          "text" => content,
          "bot_user_ids" => data["bot_user_ids"]
        }.compact
      }
    end
    private_class_method :build_message_content

    def self.build_approval_request_content(event_id:, data:)
      approval_request = ApprovalRequest.find_by(id: event_id)
      content = approval_request&.decision_text

      {
        "content" => content,
        "content_payload" => {
          "type" => "decision",
          "approval_request_id" => event_id,
          "request_type" => data["request_type"] || approval_request&.request_type,
          "status" => data["status"] || approval_request&.status,
          "action" => data["approval_request_action"],
          "adr_id" => data["adr_id"],
          "room_id" => data["room_id"],
          "message_id" => data["message_id"]
        }.compact
      }
    end
    private_class_method :build_approval_request_content

    def self.build_attention_item_content(event_id:, data:)
      attention_item = AttentionItem.find_by(id: event_id)
      content = attention_item&.title.presence || data["title"]

      {
        "content" => content,
        "content_payload" => {
          "type" => "attention_item_resolution",
          "attention_item_id" => event_id,
          "category" => data["category"] || attention_item&.category,
          "status" => data["status"] || attention_item&.status,
          "action_label" => data["action_label"],
          "target_type" => data["target_type"] || attention_item&.target_type,
          "room_id" => data["room_id"] || attention_item&.room_id,
          "project_id" => data["project_id"] || attention_item&.project_id,
          "source_type" => data["source_type"] || attention_item&.source_type,
          "source_id" => data["source_id"] || attention_item&.source_id
        }.compact
      }
    end
    private_class_method :build_attention_item_content

    def self.attachment_payload(message)
      return unless message&.attachment?

      {
        "filename" => message.attachment.filename.to_s,
        "content_type" => message.attachment.content_type,
        "byte_size" => message.attachment.blob.byte_size
      }
    end
    private_class_method :attachment_payload
  end
end