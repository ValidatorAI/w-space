module Api
  class ProjectAllHandsTakeawaysController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      takeaways = project.project_all_hands_takeaways.ordered
      if params[:active].present?
        takeaways = takeaways.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = takeaways.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_takeaways = takeaways.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_all_hands_takeaways: paged_takeaways.map { |takeaway| serialize(takeaway) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      takeaway = project.project_all_hands_takeaways.find_by(id: params[:id])
      return render json: { error: "Project all hands takeaway not found" }, status: :not_found unless takeaway

      render json: serialize(takeaway)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      takeaway = project.project_all_hands_takeaways.new(takeaway_params)
      unless takeaway.save
        return render json: { error: takeaway.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(takeaway), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      takeaway = project.project_all_hands_takeaways.find_by(id: params[:id])
      return render json: { error: "Project all hands takeaway not found" }, status: :not_found unless takeaway

      if takeaway.update(takeaway_params)
        render json: serialize(takeaway)
      else
        render json: { error: takeaway.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      takeaway = project.project_all_hands_takeaways.find_by(id: params[:id])
      return render json: { error: "Project all hands takeaway not found" }, status: :not_found unless takeaway

      takeaway.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def takeaway_params
      params.permit(:category, :content, :active, :position)
    end

    def serialize(takeaway)
      takeaway.as_json
    end
  end
end
