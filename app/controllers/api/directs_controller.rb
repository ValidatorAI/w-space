module Api
  class DirectsController < Api::BaseController
    def index
      creator = User.find_by(id: params[:creator_user_id].presence || params[:with_user_id])
      target_user_id = params[:with_user_id].presence
      direct_rooms = Rooms::Direct.includes(:users).select do |room|
        next false if creator.blank?

        room.user_ids.include?(creator.id) && (target_user_id.blank? || room.user_ids.include?(target_user_id.to_i))
      end

      render json: direct_rooms.map { |room| room.as_json(only: %i[id name type created_at updated_at]) }
    end

    def create
      creator_id = params[:creator_user_id].presence || params[:actor_user_id].presence
      user_ids = Array(params[:user_ids]).map(&:to_i).uniq
      creator = creator_id.present? ? User.find_by(id: creator_id) : (user_ids.present? ? User.find_by(id: user_ids.first) : nil)
      user_ids << creator.id if creator.present?
      users = user_ids.present? ? User.where(id: user_ids.uniq).ordered.to_a : []

      if creator.present? && !users.map(&:id).include?(creator.id)
        users << creator
      end

      room, created, = DirectRoomService.open_for(users, initial_message: params[:message], actor: creator)
      render json: { room: serialize_room(room), created: created }
    rescue ActiveRecord::RecordInvalid
      render json: { error: "Unable to create direct room" }, status: :unprocessable_entity
    end

    private
      def serialize_room(room)
        {
          id: room.id,
          type: room.type,
          name: room.name,
          members: room.users.map { |user| { id: user.id, name: user.name, display_name: user.display_name } }
        }
      end
  end
end
