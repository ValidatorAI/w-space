module Api
  class ApprovalRequestsController < Api::BaseController
    include ActionView::RecordIdentifier

    APPROVAL_REQUEST_FIELDS = %i[
      id room_id message_id agent_id request_type status requested_at resolved_at resolved_by_id created_at updated_at
    ].freeze
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      approval_requests = room.approval_requests.recent
      count = approval_requests.count

      if params[:page].present?
        per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
        page = [ params[:page].to_i, 1 ].max
        approval_requests = approval_requests.offset((page - 1) * per_page).limit(per_page)

        render json: { count: count, page: page, per_page: per_page, approval_requests: approval_requests.map { |ar| serialize(ar) } }
      else
        render json: { count: count, approval_requests: approval_requests.map { |ar| serialize(ar) } }
      end
    end

    def show
      approval_request = locate_approval_request
      return unless approval_request

      render json: serialize(approval_request)
    end

    def create
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      approval_request = room.approval_requests.new(approval_request_params)

      if approval_request.message_id.present? && approval_request.message&.room_id != room.id
        return render json: { error: "Message does not belong to the room" }, status: :unprocessable_entity
      end

      approval_request.save!
      broadcast_after_create(approval_request)

      render json: serialize(approval_request), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      approval_request = locate_approval_request
      return unless approval_request

      update_attrs = approval_request_params.to_h
      update_attrs[:resolved_at] = Time.current if status_resolved?(update_attrs[:status]) && approval_request.resolved_at.blank?

      approval_request.update!(update_attrs)
      broadcast_after_update(approval_request)

      render json: serialize(approval_request)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      approval_request = locate_approval_request
      return unless approval_request

      broadcast_after_destroy(approval_request)
      approval_request.destroy

      head :no_content
    end

    private

    def locate_approval_request
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render(json: { error: "Room not found" }, status: :not_found) && nil unless room

      approval_request = room.approval_requests.find_by(id: params[:id])
      return render(json: { error: "Approval request not found" }, status: :not_found) && nil unless approval_request

      approval_request
    end

    def approval_request_params
      params.permit(
        :message_id, :agent_id, :request_type, :status, :requested_at, :resolved_at, :resolved_by_id,
        payload: {}
      )
    end

    def status_resolved?(status)
      status.to_s.present? && ApprovalRequest.statuses.key?(status.to_s) && status.to_s != "pending"
    end

    def serialize(approval_request)
      approval_request.as_json(only: APPROVAL_REQUEST_FIELDS, methods: :decision_text)
    end

    def broadcast_after_create(approval_request)
      if approval_request.message_id.present?
        approval_request.broadcast_replace_to approval_request.room, :messages,
          target: dom_id(approval_request.message, :presentation),
          partial: "messages/presentation",
          locals: { message: approval_request.message }
      else
        approval_request.broadcast_replacement
      end
    end

    def broadcast_after_update(approval_request)
      broadcast_after_create(approval_request)
    end

    def broadcast_after_destroy(approval_request)
      if approval_request.message_id.present?
        approval_request.broadcast_replace_to approval_request.room, :messages,
          target: dom_id(approval_request.message, :presentation),
          partial: "messages/presentation",
          locals: { message: approval_request.message }
      else
        approval_request.broadcast_remove_to approval_request.room, :messages
      end
    end
  end
end
