module Api
  class MessageTopicsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      message_topics = build_scope
      count = message_topics.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_message_topics = message_topics.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        message_topics: paged_message_topics.map { |message_topic| serialize(message_topic) }
      }
    end

    def show
      message_topic = MessageTopic.find_by(id: params[:id])
      return render json: { error: "Message topic not found" }, status: :not_found unless message_topic

      render json: serialize(message_topic)
    end

    def create
      topic = Topic.find_by(id: params[:topic_id])
      return render json: { error: "Topic not found" }, status: :not_found unless topic

      message = Message.find_by(id: params[:message_id])
      return render json: { error: "Message not found" }, status: :not_found unless message

      message_topic = MessageTopic.new(topic: topic, message: message, created_date: parse_datetime(params[:created_date]))
      unless message_topic.save
        return render json: { error: message_topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(message_topic), status: :created
    end

    def update
      message_topic = MessageTopic.find_by(id: params[:id])
      return render json: { error: "Message topic not found" }, status: :not_found unless message_topic

      if params[:topic_id].present? || params.key?(:topic_id)
        topic = Topic.find_by(id: params[:topic_id])
        return render json: { error: "Topic not found" }, status: :not_found if params[:topic_id].present? && topic.nil?

        message_topic.topic = topic if topic
      end

      if params[:message_id].present? || params.key?(:message_id)
        message = Message.find_by(id: params[:message_id])
        return render json: { error: "Message not found" }, status: :not_found if params[:message_id].present? && message.nil?

        message_topic.message = message if message
      end

      message_topic.created_date = parse_datetime(params[:created_date]) if params.key?(:created_date)

      unless message_topic.save
        return render json: { error: message_topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(message_topic)
    end

    def destroy
      message_topic = MessageTopic.find_by(id: params[:id])
      return render json: { error: "Message topic not found" }, status: :not_found unless message_topic

      message_topic.destroy
      head :no_content
    end

    private

    def build_scope
      scope = MessageTopic.order(created_at: :desc)

      if params[:topic_id].present?
        scope = scope.where(topic_id: params[:topic_id])
      end

      if params[:message_id].present?
        scope = scope.where(message_id: params[:message_id])
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

    def serialize(message_topic)
      message_topic.as_json
    end
  end
end
