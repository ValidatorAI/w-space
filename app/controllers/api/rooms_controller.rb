module Api
  class RoomsController < Api::BaseController
    ROOM_FIELDS = %i[
      id name type description private parent_id project_id creator_id
      archived_at created_at updated_at
    ].freeze

    def index
      project = find_project(params[:project_id])
      rooms = project.present? ? project.rooms : Room.all

      render json: rooms.as_json(only: ROOM_FIELDS)
    end

    def show
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      render json: room.as_json(only: ROOM_FIELDS)
    end

    def threads
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:id]) : find_room(params[:id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      room_scope = project.present? ? project.rooms : Room.all
      render json: room_scope.where(parent_id: room.id).ordered.as_json(only: ROOM_FIELDS)
    end

    def search
      project = find_project(params[:project_id])
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

    private

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
