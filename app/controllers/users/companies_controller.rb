class Users::CompaniesController < ApplicationController
  before_action :set_company_context
  before_action :ensure_can_administer, only: %i[ update add_user ]

  def home
    @company_bot = FirstRun.ensure_company_bot!
    @open_attention_items = AttentionItem.for_user(Current.user).open_items.ordered
    @open_count = @open_attention_items.count
    @overdue_count = @open_attention_items.count(&:overdue?)
    @ai_count = @open_attention_items.count(&:ai_confirm?)
    @items_by_category = @open_attention_items.group_by(&:category)
  end

  def status
    @periods = CompanyStatusPeriod.includes(:company_status_items).ordered
    @selected_period = if params[:period].present?
      @periods.find { |p| p.slug == params[:period] }
    end
    @selected_period ||= @periods.find(&:current?) || @periods.first

    @periods_payload = @periods.each_with_object({}) do |period, hash|
      hash[period.slug] = period.as_status_payload
    end

    respond_to do |format|
      format.html
      format.json { render json: @periods_payload }
    end
  end

  def settings
  end

  def add_user
    @new_user = User.new

    render :add_user_modal, layout: false
  end

  def update
    group_id = SecureRandom.uuid
    previous_allowed_ids = @account.allowed_bot_user_ids
    next_allowed_ids = sanitized_allowed_bot_user_ids
    removed_ids = previous_allowed_ids - next_allowed_ids

    ActiveRecord::Base.transaction do
      @account.update!(settings: @account.settings_with_allowed_bot_user_ids(next_allowed_ids))
      remove_bot_memberships!(removed_ids) if removed_ids.any?
    end

    OutputEvents::Recorder.record(
      event_type: "account_settings_updated",
      event_id: @account.id,
      group_id: group_id,
      actor: Current.user,
      target_type: "Account",
      data: {}
    )
    if previous_allowed_ids != next_allowed_ids
      OutputEvents::Recorder.record(
        event_type: "account_bot_access_updated",
        event_id: @account.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Account",
        data: { "allowed_bot_user_ids" => next_allowed_ids, "removed_bot_user_ids" => removed_ids }
      )
    end

    redirect_to user_company_settings_path(user_id: "me"), notice: update_notice(removed_ids.count)
  end

  private
    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?
    end

    def set_company_context
      @account = Current.account
      @users = User.where(status: [ :active, :deactivated ]).without_bots.ordered.limit(50)
      @bots = User.active_bots.ordered
      @allowed_bot_user_ids = @account.allowed_bot_user_ids
      @projects = Current.user.projects.sort_by { |project| project.display_name.to_s.downcase }.first(6)
      @rooms_count = Current.user.rooms.without_directs.active.count
      @messages_this_week = Current.user.reachable_messages.where(created_at: 1.week.ago..Time.current).count
    end

    def sanitized_allowed_bot_user_ids
      ids = Array(account_params.dig(:settings, :allowed_bot_user_ids))
      normalized = ids.filter_map { |id| Integer(id, exception: false) }.uniq

      User.active_bots.where(id: normalized).pluck(:id)
    end

    def account_params
      params.fetch(:account, {}).permit(settings: { allowed_bot_user_ids: [] })
    end

    def remove_bot_memberships!(bot_user_ids)
      ProjectUser.where(user_id: bot_user_ids).delete_all
      Membership.where(participant_type: "User", participant_id: bot_user_ids).delete_all
    end

    def update_notice(removed_count)
      return "Global AI integrations updated" if removed_count.zero?

      "Global AI integrations updated; removed #{removed_count} bot(s) from all rooms and projects"
    end
end
