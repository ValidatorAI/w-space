module Api
  class RoomHistoryTopicsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      room_history_topics = build_scope
      count = room_history_topics.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_topics = room_history_topics.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        room_history_topics: paged_topics.map { |room_history_topic| serialize(room_history_topic) }
      }
    end

    def show
      room_history_topic = RoomHistoryTopic.find_by(id: params[:id])
      return render json: { error: "Room history topic not found" }, status: :not_found unless room_history_topic

      render json: serialize(room_history_topic)
    end

    def create
      room = Room.find_by(id: params[:room_id])
      return render json: { error: "Room not found" }, status: :not_found unless room

      room_history_topic = RoomHistoryTopic.new(room: room, created_date: parse_datetime(params[:created_date]), last_state: params[:last_state])
      unless room_history_topic.save
        return render json: { error: room_history_topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(room_history_topic), status: :created
    end

    def update
      room_history_topic = RoomHistoryTopic.find_by(id: params[:id])
      return render json: { error: "Room history topic not found" }, status: :not_found unless room_history_topic

      if params[:room_id].present? || params.key?(:room_id)
        room = Room.find_by(id: params[:room_id])
        return render json: { error: "Room not found" }, status: :not_found if params[:room_id].present? && room.nil?

        room_history_topic.room = room if room
      end

      room_history_topic.created_date = parse_datetime(params[:created_date]) if params.key?(:created_date)
      room_history_topic.last_state = params[:last_state] if params.key?(:last_state)

      unless room_history_topic.save
        return render json: { error: room_history_topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(room_history_topic)
    end

    def destroy
      room_history_topic = RoomHistoryTopic.find_by(id: params[:id])
      return render json: { error: "Room history topic not found" }, status: :not_found unless room_history_topic

      room_history_topic.destroy
      head :no_content
    end

    private

    def build_scope
      scope = RoomHistoryTopic.order(created_at: :desc)

      if params[:room_id].present?
        scope = scope.where(room_id: params[:room_id])
      end

      if params[:created_date].present?
        begin
          scope = scope.where("created_date >= ?", Time.zone.parse(params[:created_date].to_s))
        rescue ArgumentError
          return scope.none
        end
      end

      scope
    end

    def parse_datetime(value)
      return Time.current if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      raise ActiveRecord::RecordInvalid, "Invalid date format"
    end

    def serialize(room_history_topic)
      room_history_topic.as_json
    end
  end
end
