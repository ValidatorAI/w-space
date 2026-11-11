class MessageCreationEvents
  class << self
    def record(message:, room: message.room, mode: nil)
      return unless OutputEvents::MessageEmissionPolicy.allowed?(message: message)

      room ||= message.room
      group_id = SecureRandom.uuid

      OutputEvents::Recorder.record(
        event_type: "message_created",
        event_id: message.id,
        group_id: group_id,
        actor: message.creator,
        target_type: "Message",
        data: { "room_id" => room.id, "content_type" => message.content_type }
      )

      if message.attachment?
        OutputEvents::Recorder.record(
          event_type: "message_attachment_uploaded",
          event_id: message.id,
          group_id: group_id,
          actor: message.creator,
          target_type: "Message",
          data: { "room_id" => room.id, "filename" => message.attachment.filename.to_s }
        )
      end

      bot_ids = bot_recipients_for(message, room)
      return if !message.from_user?

      should_record_ai_question = mode.to_s == "ask" || bot_ids.present?
      return unless should_record_ai_question

      OutputEvents::Recorder.record(
        event_type: "ai_question_asked",
        event_id: message.id,
        group_id: group_id,
        actor: message.creator,
        target_type: "Message",
        data: {
          "room_id" => room.id,
          "bot_user_ids" => bot_ids,
          "mode" => mode.to_s.presence || "message"
        }
      )
    end

    private
      def bot_recipients_for(message, room)
        recipients = message.mentionees.active_bots
        recipients = room.users.active_bots if room.direct?
        recipients.pluck(:id)
      end
  end
end
