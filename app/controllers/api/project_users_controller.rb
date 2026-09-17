module Api
  class ProjectUsersController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      users = project.users.ordered
      count = users.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_users = users.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_users: paged_users.map { |user| serialize(user) }
      }
    end

    def show
      project = Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      user = project.users.find_by(id: params[:id])
      return render json: { error: "Project user not found" }, status: :not_found unless user

      render json: serialize(user)
    end

    private

    def serialize(user)
      {
        id: user.id,
        name: user.name,
        display_name: user.display_name,
        email_address: user.email_address,
        job_title: user.job_title,
        status: user.status,
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    end
  end
end
