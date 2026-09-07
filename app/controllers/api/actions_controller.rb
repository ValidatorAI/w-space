module Api
  class ActionsController < Api::BaseController
    ALLOWED_ACTIONS = %w[typing_start typing_stop].freeze

    def create
      project = find_project(params[:project_id])
      room = project.present? ? find_room(project, params[:room_id]) : find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      user = User.find_by(id: params[:user_id])
      return render json: { error: "User not found" }, status: :not_found unless user

      action = params[:action_type].to_s
      unless ALLOWED_ACTIONS.include?(action)
        return render json: { error: "Unsupported action: #{action}. Allowed: #{ALLOWED_ACTIONS.join(", ")}" }, status: :bad_request
      end

      broadcast_action(room, user, action)

      render json: { status: "ok", action: action }, status: :accepted
    end

    private

    def broadcast_action(room, user, action)
      user_attributes = { id: user.id, name: user.name }

      case action
      when "typing_start"
        TypingNotificationsChannel.broadcast_to(room, action: :start, user: user_attributes)
      when "typing_stop"
        TypingNotificationsChannel.broadcast_to(room, action: :stop, user: user_attributes)
      end
    end
  end
end
