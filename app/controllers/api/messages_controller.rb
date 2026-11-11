module Api
  class MessagesController < Api::BaseController
    MESSAGE_FIELDS = %i[
      id room_id creator_id creator_type system system_type created_at updated_at
    ].freeze
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      if params[:ids].present?
        requested_ids = params[:ids].to_s.split(/[\s,]+/).map { |id| Integer(id, exception: false) }.compact.uniq.first(100)
        messages = Message.where(id: requested_ids).ordered
        skipped_count = requested_ids.count - messages.count

        render json: {
          count: messages.count,
          skipped_count: skipped_count,
          messages: messages.map { |message| serialize(message, include_body: include_body?) }
        }
        return
      end

      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      messages = room.messages.ordered
      messages = messages.where(creator_id: params[:creator_id]) if params[:creator_id].present?
      messages = messages.where(system: parse_boolean(params[:system])) if params[:system].present?
      messages = messages.where("created_at >= ?", Time.zone.parse(params[:since].to_s)) if params[:since].present?
      messages = messages.where("created_at <= ?", Time.zone.parse(params[:until].to_s)) if params[:until].present?

      if params[:q].present?
        q = params[:q].to_s.strip
        if q.present?
          pattern = "%#{sanitize_like(q.downcase)}%"
          messages = messages.joins(:rich_text_body).where("LOWER(action_text_rich_texts.body) LIKE ? ESCAPE '\\'", pattern)
        end
      end

      count = messages.count

      if params[:page].present?
        per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
        page = [ params[:page].to_i, 1 ].max
        messages = messages.offset((page - 1) * per_page).limit(per_page)

        render json: { count: count, page: page, per_page: per_page, messages: messages.map { |message| serialize(message, include_body: include_body?) } }
      else
        render json: { count: count, messages: messages.map { |message| serialize(message, include_body: include_body?) } }
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
      message_mode = params[:mode].presence
      return render json: { error: "Provide at least one of: body, attachment" }, status: :bad_request unless body || attachment

      message = room.messages.create_with_attachment!(
        body: body, attachment: attachment, creator: user, client_message_id: SecureRandom.uuid
      )
      message.broadcast_create
      MessageCreationEvents.record(message: message, room: room, mode: message_mode)

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

      actor = User.find_by(id: params[:user_id].presence) || User.find_by(id: params[:actor_user_id].presence) || message.creator
      begin
        MessageUpdateService.call(message, body: body, attachment: attachment, actor: actor)
      rescue ArgumentError => e
        return render json: { error: e.message }, status: message.system? ? :forbidden : :unprocessable_entity
      end

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

    def serialize(message, include_body: true)
      payload = message.as_json(only: MESSAGE_FIELDS)
      payload["body"] = message.plain_text_body if include_body
      payload["has_attachment"] = message.attachment?
      payload["attachment_filename"] = message.attachment? ? message.attachment.filename.to_s : nil
      payload["attachment_content_type"] = message.attachment? ? message.attachment.content_type : nil
      payload["attachment_url"] = if message.attachment?
        if message.room.project_id.present?
          attachment_api_project_room_message_path(message.room.project_id, message.room_id, message.id)
        else
          attachment_api_room_message_path(message.room_id, message.id)
        end
      end
      payload
    end

    def include_body?
      params[:include].to_s.split(",").map(&:strip).include?("body")
    end

    def parse_boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def sanitize_like(term)
      term.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
