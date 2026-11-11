module Api
  class ProjectsController < Api::BaseController
    PROJECT_FIELDS = %i[
      id name slug path description private short_code current_phase
      progress_percent roadmap recently_completed budget_total budget_spent
      created_at updated_at
    ].freeze

    def index
      render json: Project.all.as_json(only: PROJECT_FIELDS)
    end

    def show
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      render json: serialize_project(project)
    end

    def create
      payload = project_params
      path = payload[:path].presence
      return render json: { error: "Path is required" }, status: :unprocessable_entity if path.blank?

      actor = resolve_project_actor
      result = ProjectAdminService.create(attributes: payload, actor: actor)
      project = result[:project]
      if result[:created] == false
        return render json: serialize_project(project).merge("created" => false), status: :ok
      end

      render json: serialize_project(project).merge("created" => true), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      project = ProjectAdminService.update(project: project, attributes: project_params, actor: resolve_project_actor)
      render json: serialize_project(project)
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      pending_count = ProjectAdminService.pending_approvals_count(project)
      if pending_count.positive?
        return render json: { error: "open approvals exist", pending_count: pending_count }, status: :conflict
      end

      ProjectAdminService.destroy(project, actor: resolve_project_actor)
      head :no_content
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def project_params
      source = params[:project].presence || params
      source.permit(
        :name,
        :path,
        :description,
        :private,
        :short_code,
        :current_phase,
        :roadmap,
        :recently_completed,
        :budget_total,
        :budget_spent
      )
    end

    def serialize_project(project)
      payload = project.as_json(only: PROJECT_FIELDS)
      payload["budget_total"] = normalize_numeric(payload["budget_total"])
      payload["budget_spent"] = normalize_numeric(payload["budget_spent"])
      payload["progress_percent"] = normalize_numeric(payload["progress_percent"])
      payload
    end

    def normalize_numeric(value)
      return value if value.nil?

      if value.is_a?(String)
        value = BigDecimal(value, exception: false)
        return value if value.nil?
      end

      return value unless value.is_a?(Numeric)

      number = value.to_f
      number.to_i == number ? number.to_i : number
    end

    def resolve_project_actor
      return User.find_by(id: params[:actor_user_id].presence) if params[:actor_user_id].present?
      return Mcp::FuzzyMatcher.match_user(params[:user_name]) if params[:user_name].present?
      return Mcp::FuzzyMatcher.match_user(params[:actor_user_name]) if params[:actor_user_name].present?

      nil
    end
  end
end

