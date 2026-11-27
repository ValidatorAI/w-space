module Api
  class DecisionRoomsController < Api::BaseController
    def index
      decision_rooms = DecisionRoom.order(:id)
      render json: decision_rooms
    end

    def create
      room = Room.find_by(id: params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      project_adr = ProjectAdr.find_by(id: params[:project_adr_id])
      return render json: { error: "Project ADR not found" }, status: :not_found unless project_adr

      decision_room = DecisionRoom.find_or_create_by!(room: room, project_adr: project_adr)
      render json: decision_room, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
