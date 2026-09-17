class RoomsController < ApplicationController
  before_action :set_room, only: %i[ show destroy ]
  before_action :ensure_can_administer, only: %i[ destroy ]
  before_action :remember_last_room_visited, only: :show

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    @messages = find_messages
  end

  def destroy
    room_id = @room.id
    room_data = { "room_type" => @room.type, "project_id" => @room.project_id, "parent_id" => @room.parent_id }.compact
    @room.destroy

    broadcast_remove_room
    OutputEvents::Recorder.record(
      event_type: "room_deleted",
      event_id: room_id,
      actor: Current.user,
      target_type: "Room",
      data: room_data
    )
    redirect_to root_url
  end

  private
    def set_room
      if room = Current.user.rooms.find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def ensure_permission_to_create_rooms
      if Current.account.settings.restrict_room_creation_to_administrators? && !Current.user.administrator?
        head :forbidden
      end
    end

    def find_messages
      messages = Message.where(room: @room)
        .or(Message.where(room_id: @room.child_topics.select(:id)))
        .with_creator.with_attachment_details.with_boosts

      if show_first_message = messages.find_by(id: params[:message_id])
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def broadcast_remove_room
      broadcast_remove_to :rooms, target: [ @room, :list ]
    end

    def record_room_event(event_type, room, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "room_type" => room.type, "project_id" => room.project_id, "parent_id" => room.parent_id }.compact
      )
    end
end
