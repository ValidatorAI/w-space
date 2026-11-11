class DirectRoomService
  class << self
    def open_for(users, initial_message: nil, actor: nil)
      room_users = Array(users).compact.uniq
      creator = actor || room_users.first
      room = Rooms::Direct.find_or_create_for(room_users, creator: creator)
      created = room.previously_new_record?

      message = if initial_message.present?
                  payload = initial_message.to_h.with_indifferent_access
                  room.messages.create_with_attachment!(payload) if payload[:body].to_s.strip.present? || payload["body"].to_s.strip.present? || payload[:attachment].present? || payload["attachment"].present?
                end

      if created
        group_id = SecureRandom.uuid
        record_room_event(room, "room_created", actor: actor, group_id: group_id)
        record_room_event(room, "direct_conversation_created", actor: actor, group_id: group_id)
        room.users.find_each do |member|
          record_room_member_added(room, member, actor: actor, group_id: group_id)
        end
      end

      if message.present?
        message.broadcast_create
        record_message_events(message)
      end

      [room, created, message]
    end

    private
      def record_room_event(room, event_type, actor:, group_id: nil)
        OutputEvents::Recorder.record(
          event_type: event_type,
          event_id: room.id,
          group_id: group_id,
          actor: actor,
          target_type: "Room",
          data: { "room_type" => room.type, "project_id" => room.project_id, "parent_id" => room.parent_id }.compact
        )
      end

      def record_room_member_added(room, user, actor:, group_id: nil)
        OutputEvents::Recorder.record(
          event_type: "room_member_added",
          event_id: room.id,
          group_id: group_id,
          actor: actor,
          target_type: "Room",
          data: { "member" => { "type" => "User", "id" => user.id } }
        )
      end

      def record_message_events(message)
        return unless OutputEvents::MessageEmissionPolicy.allowed?(message: message)

        group_id = SecureRandom.uuid
        OutputEvents::Recorder.record(
          event_type: "message_created",
          event_id: message.id,
          group_id: group_id,
          actor: message.creator,
          target_type: "Message",
          data: { "room_id" => message.room_id, "content_type" => message.content_type }
        )

        if message.attachment?
          OutputEvents::Recorder.record(
            event_type: "message_attachment_uploaded",
            event_id: message.id,
            group_id: group_id,
            actor: message.creator,
            target_type: "Message",
            data: { "room_id" => message.room_id, "filename" => message.attachment.filename.to_s }
          )
        end

        bot_ids = message.room.users.active_bots.excluding(message.creator).pluck(:id)
        return if !message.from_user? || bot_ids.empty?

        OutputEvents::Recorder.record(
          event_type: "ai_question_asked",
          event_id: message.id,
          group_id: group_id,
          actor: message.creator,
          target_type: "Message",
          data: { "room_id" => message.room_id, "bot_user_ids" => bot_ids }
        )
      end
  end
end
