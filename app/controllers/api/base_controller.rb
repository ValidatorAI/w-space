module Api
  class BaseController < ActionController::API
    before_action :authenticate_token!

    private

    def authenticate_token!
      expected_token = ENV["OUTPUT_EVENTS_TOKEN"].presence
      return render json: { error: "Server misconfigured" }, status: :internal_server_error unless expected_token

      provided_token = request.headers["Authorization"]&.sub(/\ABearer\s+/, "")
      return render json: { error: "Unauthorized" }, status: :unauthorized unless provided_token
      return render json: { error: "Unauthorized" }, status: :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    end

    def find_project(id)
      return nil if id.blank?

      Project.find_by(id: id) || Project.find_by(slug: id)
    end

    def find_room(project_or_id, id = nil)
      if id.nil?
        room_id = project_or_id
        project = nil
      else
        room_id = id
        project = project_or_id
      end

      return Room.find_by(id: room_id) if project.blank?

      project.rooms.find_by(id: room_id)
    end
  end
end
