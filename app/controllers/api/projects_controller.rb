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

      render json: project.as_json(only: PROJECT_FIELDS)
    end
  end
end

