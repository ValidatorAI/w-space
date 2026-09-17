module Api
  class ProjectKnowledgeItemsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      items = project.knowledge_items.ordered
      if params[:active].present?
        items = items.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = items.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_items = items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        knowledge_items: paged_items.map { |item| serialize(item) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.knowledge_items.find_by(id: params[:id])
      return render json: { error: "Knowledge item not found" }, status: :not_found unless item

      render json: serialize(item)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.knowledge_items.new(knowledge_item_params)
      unless item.save
        return render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(item), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.knowledge_items.find_by(id: params[:id])
      return render json: { error: "Knowledge item not found" }, status: :not_found unless item

      if item.update(knowledge_item_params)
        render json: serialize(item)
      else
        render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.knowledge_items.find_by(id: params[:id])
      return render json: { error: "Knowledge item not found" }, status: :not_found unless item

      item.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def knowledge_item_params
      params.permit(:title, :description, :badge, :active, :position)
    end

    def serialize(item)
      item.as_json
    end
  end
end
