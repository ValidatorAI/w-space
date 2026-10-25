class RoomChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user

    if @room = find_room
      stream_for @room
    else
      reject
    end
  end

  private
    def find_room
      return unless current_user

      current_user.rooms.find_by(id: params[:room_id])
    end
end
