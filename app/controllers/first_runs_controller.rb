class FirstRunsController < ApplicationController
  allow_unauthenticated_access only: %i[ show create ]

  before_action :redirect_if_setup_complete, only: %i[ show create ]

  def show
    @user = User.new
  end

  def create
    Account.transaction do
      @account = Account.lock.find_by(singleton_guard: 0)
      if @account.nil?
        @account = Account.create!(name: first_run_account_params[:name].presence || FirstRun::ACCOUNT_NAME, singleton_guard: 0)
      else
        @account.update!(name: first_run_account_params[:name].presence || FirstRun::ACCOUNT_NAME)
      end

      if User.exists?
        raise ActiveRecord::RecordNotUnique
      end

      @user = User.create!(user_params.merge(role: :administrator))
      Rooms::Open.create_for({ name: FirstRun::FIRST_ROOM_NAME, creator: @user }, users: [@user])
      FirstRun.ensure_company_bot!
    end

    start_new_session_for @user
    redirect_to root_url
  rescue ActiveRecord::RecordNotUnique
    redirect_to root_url
  rescue ActiveRecord::RecordInvalid
    @user ||= User.new(user_params.merge(role: :administrator))
    render :show, status: :unprocessable_entity
  end

  private
    def redirect_if_setup_complete
      redirect_to root_url if Account.any? || User.any?
    end

    def first_run_account_params
      params.fetch(:account, {}).permit(:name)
    end

    def user_params
      params.fetch(:user, {}).permit(:name, :display_name, :email_address, :password).tap do |attrs|
        attrs[:display_name] = attrs[:display_name].presence || attrs[:name]
      end
    end
end
