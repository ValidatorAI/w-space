class PresenceChannel < RoomChannel
  on_subscribe   :present, unless: :subscription_rejected?
  on_unsubscribe :absent,  unless: :subscription_rejected?

  def present
    return unless membership

    membership.present
    broadcast_read_room
  end

  def absent
    return unless membership

    membership.disconnected
  end

  def refresh
    return unless membership

    membership.refresh_connection
  end

  private
    def membership
      return unless @room && current_user

      @room.memberships.find_by(participant_type: "User", participant_id: current_user.id)
    end

    def broadcast_read_room
      return unless membership && current_user

      ActionCable.server.broadcast "user_#{current_user.id}_reads", { room_id: membership.room_id }
    end
end
