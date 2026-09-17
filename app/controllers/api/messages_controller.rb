module Api
  class MessagesController < Api::BaseController
    MESSAGE_FIELDS = %i[
      id room_id creator_id creator_type system system_type created_at updated_at
    ].freeze
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      messages = room.messages.ordered
      count = messages.count

      if params[:page].present?
        per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
        page = [ params[:page].to_i, 1 ].max
        messages = messages.offset((page - 1) * per_page).limit(per_page)

        render json: { count: count, page: page, per_page: per_page, messages: messages.map { |message| serialize(message) } }
      else
        render json: { count: count, messages: messages.map { |message| serialize(message) } }
      end
    end

    def show
      message = locate_message
      return unless message

      render json: serialize(message)
    end

    def attachment
      message = locate_message
      return unless message

      return render json: { error: "Message has no attachment" }, status: :not_found unless message.attachment?

      send_data message.attachment.download,
                filename: message.attachment.filename.to_s,
                type: message.attachment.content_type,
                disposition: params[:disposition] == "attachment" ? :attachment : :inline
    end

    def create
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      user = User.find_by(id: params[:user_id])
      return render json: { error: "User not found" }, status: :not_found unless user

      body = params[:body].presence
      attachment = params[:attachment].presence
      return render json: { error: "Provide at least one of: body, attachment" }, status: :bad_request unless body || attachment

      message = room.messages.create_with_attachment!(
        body: body, attachment: attachment, creator: user, client_message_id: SecureRandom.uuid
      )
      message.broadcast_create

      render json: serialize(message), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      message = locate_message
      return unless message

      body = params[:body].presence
      attachment = params[:attachment].presence
      return render json: { error: "Provide at least one of: body, attachment" }, status: :bad_request unless body || attachment

      message.update!(body: body) if body
      message.attachment.attach(attachment) && message.process_attachment if attachment

      message.broadcast_replace_to message.room, :messages, target: [ message, :presentation ], partial: "messages/presentation", attributes: { maintain_scroll: true }

      render json: serialize(message)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      message = locate_message
      return unless message

      message.destroy
      message.broadcast_remove

      head :no_content
    end

    private

    # Resolves a message either via the nested project/room path or the flat /api/messages/:id path (message ids are globally unique).
    def locate_message
      if params[:room_id].present?
        project = find_project(params[:project_id])
        room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
        return render(json: { error: "Room not found" }, status: :not_found) && nil unless room

        message = room.messages.find_by(id: params[:id])
      else
        message = Message.find_by(id: params[:id])
      end

      return render(json: { error: "Message not found" }, status: :not_found) && nil unless message

      message
    end

    def serialize(message)
      message.as_json(only: MESSAGE_FIELDS).merge(
        body: message.plain_text_body,
        has_attachment: message.attachment?,
        attachment_filename: message.attachment? ? message.attachment.filename.to_s : nil,
        attachment_content_type: message.attachment? ? message.attachment.content_type : nil,
        attachment_url: message.attachment? ? attachment_api_project_room_message_path(message.room.project_id, message.room_id, message.id) : nil
      )
    end
  end
end
