module Message::Broadcasts
  def broadcast_create
    broadcast_append_to room, :messages, target: [ room, :messages ]
    broadcast_to_parent_room
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id })
  end

  def broadcast_remove
    broadcast_remove_to room, :messages
    broadcast_remove_from_parent_room
  end

  private
    def broadcast_to_parent_room
      return unless room.parent.present?

      parent_room = room.parent

      broadcast_append_to parent_room, :messages,
        target: [ parent_room, :messages ],
        partial: "messages/message",
        locals: { message: self, parent_room: parent_room }

      ActionCable.server.broadcast("unread_rooms", { roomId: parent_room.id })
    end

    def broadcast_remove_from_parent_room
      return unless room.parent.present?

      parent_room = room.parent

      broadcast_remove_to parent_room, :messages
    end
end
