class MessagesController < ApplicationController
  include ActiveStorage::SetCurrent, RoomScoped
  allow_unauthenticated_access only: :last_messages

  before_action :set_room, except: %i[ create last_messages ]
  before_action :set_message, only: %i[ show edit update destroy ]
  before_action :ensure_can_administer, only: %i[ edit update destroy ]

  layout false, only: :index

  def index
    @messages = find_paged_messages

    if @messages.any?
      fresh_when @messages
    else
      head :no_content
    end
  end

  def create
    set_room
    @message = @room.messages.create_with_attachment!(message_params)

    @message.broadcast_create
    record_created_message_events
    deliver_webhooks_to_bots
  rescue ActiveRecord::RecordNotFound
    render action: :room_not_found
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def show
  end

  def edit
  end

  def update
    @message.update!(message_params)

    @message.broadcast_replace_to @room, :messages, target: [ @message, :presentation ], partial: "messages/presentation", attributes: { maintain_scroll: true }
    OutputEvents::Recorder.record(
      event_type: "message_updated",
      event_id: @message.id,
      actor: Current.user,
      target_type: "Message",
      data: { "room_id" => @room.id }
    )
    redirect_to room_message_url(@room, @message)
  end

  def destroy
    message_id = @message.id
    @message.destroy
    @message.broadcast_remove
    OutputEvents::Recorder.record(
      event_type: "message_deleted",
      event_id: message_id,
      actor: Current.user,
      target_type: "Message",
      data: { "room_id" => @room.id }
    )
  end

  def last_messages
    last_id = params[:last_id].to_i

    if params[:last_id].blank? || last_id <= 0
      return render json: { error: "last_id parameter is required and must be a positive integer" }, status: :bad_request
    end

    messages = Message.where("id > ?", last_id).ordered
    render json: messages.map { |message| serialize_message(message) }
  end

  private
    def set_message
      @message = @room.messages.find(params[:id])
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@message)
    end


    def find_paged_messages
      case
      when params[:before].present?
        @room.messages.with_creator.page_before(@room.messages.find(params[:before]))
      when params[:after].present?
        @room.messages.with_creator.page_after(@room.messages.find(params[:after]))
      else
        @room.messages.with_creator.last_page
      end
    end


    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end

    def record_created_message_events
      return unless OutputEvents::MessageEmissionPolicy.allowed?(message: @message)

      group_id = SecureRandom.uuid
      OutputEvents::Recorder.record(
        event_type: "message_created",
        event_id: @message.id,
        group_id: group_id,
        actor: @message.creator,
        target_type: "Message",
        data: { "room_id" => @room.id, "content_type" => @message.content_type }
      )

      if @message.attachment?
        OutputEvents::Recorder.record(
          event_type: "message_attachment_uploaded",
          event_id: @message.id,
          group_id: group_id,
          actor: @message.creator,
          target_type: "Message",
          data: { "room_id" => @room.id, "filename" => @message.attachment.filename.to_s }
        )
      end

      bot_ids = bot_recipients_for(@message)
      return if !@message.from_user? || bot_ids.empty?

      OutputEvents::Recorder.record(
        event_type: "ai_question_asked",
        event_id: @message.id,
        group_id: group_id,
        actor: @message.creator,
        target_type: "Message",
        data: { "room_id" => @room.id, "bot_user_ids" => bot_ids }
      )
    end

    def bot_recipients_for(message)
      recipients = message.mentionees.active_bots
      recipients = @room.users.active_bots if @room.direct?
      recipients.pluck(:id)
    end


    def deliver_webhooks_to_bots
      bots_eligible_for_webhook.excluding(@message.creator).each { |bot| bot.deliver_webhook_later(@message) }
    end

    def bots_eligible_for_webhook
      @room.direct? ? @room.users.active_bots : @message.mentionees.active_bots
    end

    def serialize_message(message)
      {
        id: message.id,
        room_id: message.room_id,
        creator_id: message.creator_id,
        creator_type: message.creator_type,
        body: message.plain_text_body,
        client_message_id: message.client_message_id,
        created_at: message.created_at,
        updated_at: message.updated_at
      }
    end
end
