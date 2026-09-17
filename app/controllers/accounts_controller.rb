class AccountsController < ApplicationController
  before_action :ensure_can_administer, only: :update
  before_action :set_account

  def edit
    users = account_users.ordered.without_bots
    @administrators, @members = users.partition(&:administrator?)
    set_page_and_extract_portion_from users, per_page: 500
  end

  def update
    @account.update!(account_params)
    OutputEvents::Recorder.record(
      event_type: "account_settings_updated",
      event_id: @account.id,
      actor: Current.user,
      target_type: "Account",
      data: { "changed_fields" => @account.previous_changes.except("updated_at").keys }
    )
    redirect_after_update
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.require(:account).permit(:name, :logo, settings: {})
    end

    def redirect_after_update
      if params[:return_to] == "company_settings"
        redirect_to user_company_settings_path(user_id: "me"), notice: "✓"
      else
        redirect_to edit_account_url, notice: "✓"
      end
    end

    def account_users
      if Current.user.can_administer?
        User.where(status: [ :active, :banned ])
      else
        User.active
      end
    end
end
