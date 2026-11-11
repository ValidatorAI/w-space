module Api
  class RoomMembersController < Api::BaseController
    def index
      room = find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      memberships = params[:all].present? ? room.memberships.includes(:participant) : room.memberships.visible.includes(:participant)
      render json: memberships.map { |membership| serialize_membership(room, membership) }
    end

    def create
      room = find_room(params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      user = resolve_user_from_params
      return render json: { error: "User not found" }, status: :not_found unless user

      if room.users.exists?(id: user.id)
        render json: { already_member: true }, status: :ok
        return
      end

      room.memberships.grant_to(user)
      record_room_membership_event(room, user, actor: actor_from_params)
      render json: { already_member: false, user_id: user.id }, status: :created
    end

    def destroy
      room = find_room(params[:room_id])
      return head :no_content unless room

      room.memberships.where(participant_type: "User", participant_id: params[:id]).destroy_all
      head :no_content
    end

    private
      def resolve_user_from_params
        user_id = params[:user_id].presence || params[:user][:user_id].presence if params[:user].present?
        return User.find_by(id: user_id) if user_id.present?

        user_name = params[:user_name].presence || params[:user].try(:[], :user_name).presence
        return Mcp::FuzzyMatcher.match_user(user_name) if user_name.present?

        nil
      end

      def actor_from_params
        user_id = params[:actor_user_id].presence || params[:actor_id].presence
        User.find_by(id: user_id)
      end

      def find_room(room_id)
        Room.find_by(id: room_id)
      end

      def record_room_membership_event(room, user, actor:)
        OutputEvents::Recorder.record(
          event_type: "room_member_added",
          event_id: room.id,
          actor: actor,
          target_type: "Room",
          data: { "member" => { "type" => "User", "id" => user.id } }
        )
      end

      def serialize_membership(room, membership)
        participant = membership.participant
        {
          user_id: participant&.id,
          name: participant&.name,
          role: participant&.role,
          involvement: membership.involvement
        }
      end
  end
end
