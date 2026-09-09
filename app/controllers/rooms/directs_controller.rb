class Rooms::DirectsController < RoomsController
  before_action :set_room, only: %i[ edit destroy ]
  def new
    @room = Rooms::Direct.new
  end

  def create
    room = Rooms::Direct.find_or_create_for(selected_users)
    message = create_initial_message(room) if initial_message?

    broadcast_create_room(room)
    if room.previously_new_record?
      group_id = SecureRandom.uuid
      record_room_event("room_created", room, group_id: group_id)
      record_room_event("direct_conversation_created", room, group_id: group_id)
      room.users.find_each { |user| record_room_member_added(room, user, group_id: group_id) }
    end
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
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end

    def create_initial_message(room)
      room.messages.create_with_attachment!(message_params)
    end

    def dispatch_created_message(message)
      message.broadcast_create
      record_created_message_events(message)
      deliver_webhooks_to_bots(message)
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

    def deliver_webhooks_to_bots(message)
      message.room.users.active_bots.excluding(message.creator).each { |bot| bot.deliver_webhook_later(message) }
    end

    # All users in a direct room can administer it
    def ensure_can_administer
      true
    end
end
