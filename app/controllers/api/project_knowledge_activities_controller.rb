module Api
  class ProjectKnowledgeActivitiesController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      activities = project.knowledge_activities.ordered
      if params[:active].present?
        activities = activities.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = activities.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_activities = activities.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        knowledge_activities: paged_activities.map { |activity| serialize(activity) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      activity = project.knowledge_activities.find_by(id: params[:id])
      return render json: { error: "Knowledge activity not found" }, status: :not_found unless activity

      render json: serialize(activity)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      activity = project.knowledge_activities.new(activity_params)
      unless activity.save
        return render json: { error: activity.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(activity), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      activity = project.knowledge_activities.find_by(id: params[:id])
      return render json: { error: "Knowledge activity not found" }, status: :not_found unless activity

      if activity.update(activity_params)
        render json: serialize(activity)
      else
        render json: { error: activity.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      activity = project.knowledge_activities.find_by(id: params[:id])
      return render json: { error: "Knowledge activity not found" }, status: :not_found unless activity

      activity.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def activity_params
      params.permit(:actor_name, :actor_color, :action_text, :target_path, :target_url, :active, :position)
    end

    def serialize(activity)
      activity.as_json
    end
  end
end
