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

      render json: rooms.as_json(only: ROOM_FIELDS)
    end

    def show
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      render json: room.as_json(only: ROOM_FIELDS)
    end

    def threads
      project = find_project_or_render_not_found(params[:project_id])
      return if params[:project_id].present? && project.nil?

      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      room_scope = project.present? ? project.rooms : Room.all
      render json: room_scope.where(parent_id: room.id).ordered.as_json(only: ROOM_FIELDS)
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

      render json: ranked.as_json(only: ROOM_FIELDS)
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
