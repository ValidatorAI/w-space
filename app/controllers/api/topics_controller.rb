module Api
  class TopicsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      topics = build_scope
      count = topics.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_topics = topics.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        topics: paged_topics.map { |topic| serialize(topic) }
      }
    end

    def show
      topic = Topic.find_by(id: params[:id])
      return render json: { error: "Topic not found" }, status: :not_found unless topic

      render json: serialize(topic)
    end

    def create
      project = find_project(params[:project_id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      topic = project.topics.new(topic_params)
      unless topic.save
        return render json: { error: topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(topic), status: :created
    end

    def update
      topic = Topic.find_by(id: params[:id])
      return render json: { error: "Topic not found" }, status: :not_found unless topic

      if params[:project_id].present? || params.key?(:project_id)
        project = find_project(params[:project_id])
        return render json: { error: "Project not found" }, status: :not_found unless project

        topic.project = project
      end

      if params[:parent_topic_id].present? || params.key?(:parent_topic_id)
        parent_topic = params[:parent_topic_id].present? ? Topic.find_by(id: params[:parent_topic_id]) : nil
        return render json: { error: "Parent topic not found" }, status: :not_found if params[:parent_topic_id].present? && parent_topic.nil?

        topic.parent_topic = parent_topic
      end

      topic.assign_attributes(topic_params)
      unless topic.save
        return render json: { error: topic.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(topic)
    end

    def destroy
      topic = Topic.find_by(id: params[:id])
      return render json: { error: "Topic not found" }, status: :not_found unless topic

      topic.destroy
      head :no_content
    end

    private

    def build_scope
      scope = Topic.order(created_at: :desc)

      if params[:project_id].present?
        scope = scope.where(project_id: params[:project_id])
      end

      if params[:active].present?
        scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      if params[:need_an_action].present?
        scope = scope.where(need_an_action: ActiveModel::Type::Boolean.new.cast(params[:need_an_action]))
      end

      if params[:room_id].present?
        scope = scope
          .joins(:message_topics)
          .joins("INNER JOIN messages ON messages.id = message_topics.message_id")
          .where(messages: { room_id: params[:room_id] })
          .distinct
      end

      if params[:parent_topic_id].present?
        scope = scope.where(parent_topic_id: params[:parent_topic_id])
      end

      scope
    end

    def topic_params
      params.permit(
        :project_id,
        :parent_topic_id,
        :name,
        :related_topics,
        :active,
        :importance_level,
        :memory,
        :state,
        :need_an_action,
        :required_actions
      )
    end

    def serialize(topic)
      topic.as_json
    end
  end
end
