module Api
  class ProjectAllHandsActionItemsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      action_items = project.project_all_hands_action_items.ordered
      if params[:active].present?
        action_items = action_items.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = action_items.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_action_items = action_items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_all_hands_action_items: paged_action_items.map { |item| serialize(item) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      action_item = project.project_all_hands_action_items.find_by(id: params[:id])
      return render json: { error: "Project all hands action item not found" }, status: :not_found unless action_item

      render json: serialize(action_item)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      action_item = project.project_all_hands_action_items.new(action_item_params)
      if action_item.completed && action_item.completed_at.blank?
        action_item.completed_at = Time.current
      end

      unless action_item.save
        return render json: { error: action_item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(action_item), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      action_item = project.project_all_hands_action_items.find_by(id: params[:id])
      return render json: { error: "Project all hands action item not found" }, status: :not_found unless action_item

      attrs = action_item_params
      if attrs.key?(:completed)
        completed_val = ActiveModel::Type::Boolean.new.cast(attrs[:completed])
        if completed_val && !action_item.completed? && !attrs.key?(:completed_at)
          attrs = attrs.merge(completed_at: Time.current)
        elsif !completed_val && action_item.completed? && !attrs.key?(:completed_at)
          attrs = attrs.merge(completed_at: nil)
        end
      end

      if action_item.update(attrs)
        render json: serialize(action_item)
      else
        render json: { error: action_item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      action_item = project.project_all_hands_action_items.find_by(id: params[:id])
      return render json: { error: "Project all hands action item not found" }, status: :not_found unless action_item

      action_item.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def action_item_params
      params.permit(:title, :assignee_name, :due_date, :completed, :completed_at, :active, :position)
    end

    def serialize(action_item)
      action_item.as_json
    end
  end
end
