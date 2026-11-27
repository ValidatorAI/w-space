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

    def create
      project = Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      user = resolve_user_from_params
      return render json: { error: "User not found" }, status: :not_found unless user
      return render json: { error: "bots cannot be project members" }, status: :unprocessable_entity if user.bot?
      return render json: { already_member: true }, status: :ok if project.users.exists?(id: user.id)

      ProjectMembershipService.add(project, user, actor: actor_from_params)
      render json: { already_member: false, user_id: user.id }, status: :created
    end

    def destroy
      project = Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
      return head :no_content unless project

      user = project.users.find_by(id: params[:id])
      ProjectMembershipService.remove(project, user, actor: actor_from_params) if user.present?
      head :no_content
    end

    private

    def resolve_user_from_params
      if params[:user_id].present?
        User.find_by(id: params[:user_id])
      elsif params[:user_name].present?
        Mcp::FuzzyMatcher.match_user(params[:user_name])
      elsif params[:user].present?
        user_id = params[:user][:user_id].presence
        return User.find_by(id: user_id) if user_id.present?

        user_name = params[:user][:user_name].presence
        Mcp::FuzzyMatcher.match_user(user_name) if user_name.present?
      end
    end

    def actor_from_params
      User.find_by(id: params[:actor_user_id].presence || params[:actor_id].presence)
    end

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
