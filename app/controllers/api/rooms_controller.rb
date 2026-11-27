module Api
  class RoomsController < Api::BaseController
    ROOM_FIELDS = %i[
      id name type description private parent_id project_id creator_id
      archived_at created_at updated_at
    ].freeze

    def index
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      rooms = project.present? ? project.rooms : Room.all

      render json: rooms.map { |room| serialize_room(room) }
    end

    def show
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      render json: serialize_room(room)
    end

    def create
      actor = resolve_api_actor
      if account_restricts_room_creation?(actor)
        return render json: { error: "room creation restricted to administrators" }, status: :forbidden
      end

      project_id = params[:project_id].presence || params.dig(:room, :project_id).presence
      project = project_id.present? ? find_project(project_id) : nil
      return render json: { error: "Project not found" }, status: :not_found if project_id.present? && project.nil?

      parent_id = params[:parent_room_id].presence || params.dig(:room, :parent_room_id).presence
      parent = nil
      if parent_id.present?
        parent = Room.find_by(id: parent_id)
        return render json: { error: "Room not found" }, status: :not_found unless parent
      end

      project ||= parent&.project

      if project.present? && parent.present? && parent.project_id != project.id
        return render json: { error: "parent room does not belong to this project" }, status: :unprocessable_entity
      end

      room = RoomCreationService.create(
        name: room_name,
        description: room_description,
        private: room_private,
        project_id: project&.id,
        parent_room_id: parent&.id,
        user_ids: normalized_user_ids,
        actor: actor
      )

      render json: serialize_room(room), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      room = Room.find_by(id: params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room
      return render json: { error: "Room is archived" }, status: :unprocessable_entity if room.archived?

      room.update!(room_update_params)
      actor = resolve_api_actor
      OutputEvents::Recorder.record(
        event_type: "room_updated",
        event_id: room.id,
        group_id: SecureRandom.uuid,
        actor: actor,
        target_type: "Room",
        data: { "room_type" => room.type, "project_id" => room.project_id, "parent_id" => room.parent_id }.compact
      )
      render json: serialize_room(room)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def threads
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      room_scope = project.present? ? project.rooms : Room.all
      render json: room_scope.where(parent_id: room.id).ordered.map { |item| serialize_room(item) }
    end

    def search
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      query = params[:q].to_s.strip
      return render json: { error: "Missing query param: q" }, status: :bad_request if query.blank?

      matches = if project.present?
                  project.rooms.where("name LIKE ? ESCAPE '\\'", "%#{sanitize_like(query)}%")
                else
                  Room.where("name LIKE ? ESCAPE '\\'", "%#{sanitize_like(query)}%")
                end
      ranked = matches.sort_by { |room| relevance_rank(room.name.to_s, query) }

      render json: ranked.map { |room| serialize_room(room) }
    end

    def members
      room = find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      if request.post?
        user = resolve_member_user
        return render json: { error: "User not found" }, status: :not_found unless user
        return render json: { already_member: true }, status: :ok if room.users.exists?(id: user.id)

        room.memberships.grant_to(user)
        OutputEvents::Recorder.record(
          event_type: "room_member_added",
          event_id: room.id,
          actor: User.find_by(id: params[:actor_user_id].presence || params[:actor_id].presence),
          target_type: "Room",
          data: { "member" => { "type" => "User", "id" => user.id } }
        )
        render json: { already_member: false, user_id: user.id }, status: :created
      else
        memberships = params[:all].present? ? room.memberships.includes(:participant) : room.memberships.visible.includes(:participant)
        render json: memberships.map do |membership|
          participant = membership.participant
          { user_id: participant&.id, name: participant&.name, role: participant&.role, involvement: membership.involvement }
        end
      end
    end

    private

    def resolve_member_user
      user_id = params[:user_id].presence || params[:user]&.[](:user_id).presence
      return User.find_by(id: user_id) if user_id.present?

      user_name = params[:user_name].presence || params[:user]&.[](:user_name).presence
      return Mcp::FuzzyMatcher.match_user(user_name) if user_name.present?

      nil
    end

    def room_name
      params[:name].presence || params.dig(:room, :name).presence
    end

    def room_description
      params[:description].presence || params.dig(:room, :description).presence
    end

    def room_private
      cast_boolean(params[:private].presence || params.dig(:room, :private).presence || false)
    end

    def room_update_params
      params.permit(:name, :description, :private)
    end

    def normalized_user_ids
      raw = Array(params[:user_ids]).flatten + Array(params.dig(:room, :user_ids)).flatten
      raw.filter_map { |entry| Integer(entry, exception: false) if entry.present? }
    end

    def resolve_project_for_creation
      explicit_project = params[:project_id].presence || params.dig(:room, :project_id).presence
      return find_project(explicit_project) if explicit_project.present?

      parent = Room.find_by(id: params[:parent_room_id].presence || params.dig(:room, :parent_room_id).presence)
      parent&.project
    end

    def account_restricts_room_creation?(actor)
      return false if actor.blank?
      return false unless Account.first&.settings&.restrict_room_creation_to_administrators?

      !actor.administrator?
    end

    def serialize_room(room)
      payload = room.as_json(only: ROOM_FIELDS)
      payload["members"] = room.users.order(:id).map do |user|
        { "user_id" => user.id, "name" => user.name }
      end
      payload
    end

    def sanitize_like(term)
      term.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end

    def relevance_rank(name, query)
      normalized_name = name.downcase
      normalized_query = query.downcase

      return 0 if normalized_name == normalized_query
      return 1 if normalized_name.start_with?(normalized_query)
      return 2 if normalized_name.include?(normalized_query)

      3
    end
  end
end
