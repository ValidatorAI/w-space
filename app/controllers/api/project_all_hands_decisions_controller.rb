module Api
  class ProjectAllHandsDecisionsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      decisions = project.project_all_hands_decisions.ordered
      if params[:active].present?
        decisions = decisions.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = decisions.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_decisions = decisions.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_all_hands_decisions: paged_decisions.map { |decision| serialize(decision) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      decision = project.project_all_hands_decisions.find_by(id: params[:id])
      return render json: { error: "Project all hands decision not found" }, status: :not_found unless decision

      render json: serialize(decision)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      decision = project.project_all_hands_decisions.new(decision_params)
      unless decision.save
        return render json: { error: decision.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(decision), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      decision = project.project_all_hands_decisions.find_by(id: params[:id])
      return render json: { error: "Project all hands decision not found" }, status: :not_found unless decision

      if decision.update(decision_params)
        render json: serialize(decision)
      else
        render json: { error: decision.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      decision = project.project_all_hands_decisions.find_by(id: params[:id])
      return render json: { error: "Project all hands decision not found" }, status: :not_found unless decision

      decision.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def decision_params
      params.permit(:title, :basis, :impact, :badge, :active, :position)
    end

    def serialize(decision)
      decision.as_json
    end
  end
end
