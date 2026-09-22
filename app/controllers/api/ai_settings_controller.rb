module Api
  class AiSettingsController < Api::BaseController
    AI_SETTING_FIELDS = %i[id label setting_value created_at updated_at].freeze

    def index
      ai_settings = AiSetting.order(:label, :id)
      render json: {
        count: ai_settings.count,
        ai_settings: ai_settings.as_json(only: AI_SETTING_FIELDS)
      }
    end

    def show
      ai_setting = AiSetting.find_by(id: params[:id])
      return render json: { error: "AI setting not found" }, status: :not_found unless ai_setting

      render json: ai_setting.as_json(only: AI_SETTING_FIELDS)
    end
  end
end
