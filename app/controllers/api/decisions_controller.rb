module Api
  class DecisionsController < Api::BaseController
    DECISION_ACTIONS = %w[approve confirm deny cancel].freeze
    APPROVAL_REQUEST_FIELDS = %i[
      id room_id message_id agent_id request_type status requested_at resolved_at resolved_by_id
    ].freeze

    def create
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      user = User.find_by(id: params[:user_id])
      return render json: { error: "User not found" }, status: :not_found unless user

      approval_request = room.approval_requests.find_by(id: params[:approval_request_id])
      return render json: { error: "Approval request not found" }, status: :not_found unless approval_request

      decision = params[:decision].to_s
      unless DECISION_ACTIONS.include?(decision)
        return render json: { error: "Unsupported decision: #{decision}. Allowed: #{DECISION_ACTIONS.join(", ")}" }, status: :bad_request
      end

      approval_request.public_send("#{decision}!", user, note: params[:note])

      render json: approval_request.as_json(only: APPROVAL_REQUEST_FIELDS)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
