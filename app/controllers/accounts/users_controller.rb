class Accounts::UsersController < ApplicationController
  before_action :ensure_can_administer, only: :create
  before_action :ensure_can_administer, :set_user, only: %i[ update destroy activate ]

  def index
    set_page_and_extract_portion_from User.active.ordered.without_bots, per_page: 500
  end

  def create
    user = User.new(create_user_params)
    user.display_name = user.name if user.display_name.blank?

    if user.save
      OutputEvents::Recorder.record(
        event_type: "user_activated",
        event_id: user.id,
        actor: Current.user,
        target_type: "User",
        data: { "created" => true }
      )
      if company_settings_modal_request?
        render "users/companies/add_user_success", layout: false
      else
        redirect_after_member_change(notice: "User added")
      end
    else
      if company_settings_modal_request?
        @new_user = user
        render "users/companies/add_user_modal", layout: false, status: :unprocessable_entity
      else
        redirect_after_member_change(alert: user.errors.full_messages.to_sentence.presence || "Unable to add user")
      end
    end
  rescue ActiveRecord::RecordNotUnique
    if company_settings_modal_request?
      @new_user = User.new(create_user_params.except(:password))
      @new_user.errors.add(:email_address, "is already in use")
      render "users/companies/add_user_modal", layout: false, status: :unprocessable_entity
    else
      redirect_after_member_change(alert: "Email address is already in use")
    end
  end

  def update
    @user.update(role_params)
    redirect_after_member_change
  end

  def destroy
    @user.deactivate
    record_user_status_event("user_deactivated")
    redirect_after_member_change
  end

  def activate
    @user.update!(status: :active)
    record_user_status_event("user_activated")
    redirect_after_member_change
  end

  private
    def set_user
      @user = User.where(status: [ :active, :deactivated ]).without_bots.find(params[:user_id] || params[:id])
    end

    def redirect_after_member_change(notice: nil, alert: nil)
      if params[:return_to] == "company_settings"
        redirect_to user_company_settings_path(user_id: "me"), notice: notice, alert: alert
      else
        redirect_to edit_account_url, notice: notice, alert: alert
      end
    end

    def company_settings_modal_request?
      params[:return_to] == "company_settings" && params[:modal_source] == "company_add_user_modal"
    end

    def role_params
      { role: params.require(:user)[:role].presence_in(%w[ member administrator ]) || "member" }
    end

    def create_user_params
      params.require(:user).permit(:name, :email_address, :password)
    end

    def record_user_status_event(event_type)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: @user.id,
        actor: Current.user,
        target_type: "User",
        data: {}
      )
    end
end
