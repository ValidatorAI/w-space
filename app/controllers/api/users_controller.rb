module Api
  class UsersController < Api::BaseController
    USER_FIELDS = %i[id name display_name email_address role status created_at updated_at].freeze

    def index
      include_bots = params[:include_bots].to_s == "true"
      scope = User.active.ordered
      scope = scope.without_bots unless include_bots
      render json: scope.as_json(only: USER_FIELDS)
    end

    def show
      user = User.find_by(id: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user

      render json: serialize_user(user)
    end

    def create
      attrs = user_params.to_h
      user = UserAdminService.create(attrs, actor: actor_from_params)
      render json: serialize_user(user), status: :created
    rescue UserAdminService::DuplicateEmailError => e
      render json: { error: e.message }, status: :conflict
    rescue UserAdminService::ValidationError => e
      render json: { error: e.record.errors.full_messages.to_sentence.presence || "Invalid user" }, status: :unprocessable_entity
    end

    def update
      user = User.find_by(id: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user

      UserAdminService.update(user, user_params)
      render json: serialize_user(user.reload)
    end

    def destroy
      user = User.find_by(id: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user

      UserAdminService.deactivate(user, actor: actor_from_params)
      head :no_content
    end

    def activate
      user = User.find_by(id: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user

      UserAdminService.activate(user, actor: actor_from_params)
      render json: serialize_user(user.reload)
    end

    private
      def actor_from_params
        user_id = params[:actor_user_id].presence || params[:user_id].presence || params[:actor_id].presence
        User.find_by(id: user_id)
      end

      def serialize_user(user)
        user.as_json(only: USER_FIELDS)
      end

      def user_params
        params.fetch(:user, params).permit(:name, :display_name, :email_address, :password, :role)
      end
  end
end
