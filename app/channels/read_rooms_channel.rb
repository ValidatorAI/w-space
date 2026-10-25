class ReadRoomsChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user

    stream_from "user_#{current_user.id}_reads"
  end
end
