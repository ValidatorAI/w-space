class Rooms::DirectsController < RoomsController
  before_action :set_room, only: %i[ edit destroy ]
  def new
    @room = Rooms::Direct.new
  end

  def create
    room, created, message = DirectRoomService.open_for(selected_users, initial_message: params[:message], actor: Current.user)

    broadcast_create_room(room)
    dispatch_created_message(message) if message
    redirect_to room_url(room)
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def edit
  end

  private
    def selected_users
      User.where(id: selected_users_ids.including(Current.user.id))
    end

    def selected_users_ids
      params.fetch(:user_ids, [])
    end

    def initial_message?
      params[:message].present? && params[:message][:body].to_s.strip.present?
    end

    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id, :mode)
    end

    def create_initial_message(room)
      room.messages.create_with_attachment!(message_params.to_h.except(:mode))
    end

    def dispatch_created_message(message)
      message.broadcast_create
      record_created_message_events(message)
    end

    def broadcast_create_room(room)
      room.memberships.each do |membership|
        membership.broadcast_prepend_to membership.user, :rooms, target: :direct_rooms, partial: "users/sidebars/rooms/direct"
      end
    end

    def record_room_member_added(room, user, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: "room_member_added",
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "member" => { "type" => "User", "id" => user.id } }
      )
    end

    def record_created_message_events(message)
      MessageCreationEvents.record(message: message, room: message.room, mode: message_params[:mode])
    end

    # All users in a direct room can administer it
    def ensure_can_administer
      true
    end
end
