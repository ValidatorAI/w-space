class Accounts::BotsController < ApplicationController
  before_action :ensure_can_administer
  before_action :set_bot, only: %i[ edit update destroy ]

  def index
    @bots = User.active_bots.ordered
  end

  def new
    @bot = User.active_bots.new
  end

  def create
    bot = User.create_bot! bot_params
    record_bot_event("bot_created", bot)
    redirect_to account_bots_url(return_to: return_to_param)
  end

  def edit
  end

  def update
    @bot.update_bot! bot_params
    record_bot_event("bot_updated", @bot)
    redirect_to account_bots_url(return_to: return_to_param)
  end

  def destroy
    @bot.deactivate
    record_bot_event("bot_deleted", @bot)
    redirect_to account_bots_url(return_to: return_to_param)
  end

  private
    def return_to_param
      "company_settings" if params[:return_to] == "company_settings"
    end

    def set_bot
      @bot = User.active_bots.find(params[:id])
    end

    def bot_params
      params.require(:user).permit(:name, :avatar, :webhook_url)
    end

    def record_bot_event(event_type, bot)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: bot.id,
        actor: Current.user,
        target_type: "User",
        data: {}
      )
    end
end
