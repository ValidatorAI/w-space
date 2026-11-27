module Api
  class AiSettingsController < Api::BaseController
    include AiAdminEvents

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

    def create
      ai_setting = AiSetting.new(ai_setting_params)
      if ai_setting.save
        record_ai_admin_event(
          event_type: "ai_setting_created",
          record: ai_setting,
          data: ai_setting_event_data(ai_setting),
          actor: resolve_api_actor
        )
        render json: ai_setting.as_json(only: AI_SETTING_FIELDS), status: :created
      else
        render json: { error: ai_setting.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def update
      ai_setting = AiSetting.find_by(id: params[:id])
      return render json: { error: "AI setting not found" }, status: :not_found unless ai_setting

      if ai_setting.update(ai_setting_params)
        record_ai_admin_event(
          event_type: "ai_setting_updated",
          record: ai_setting,
          data: ai_setting_event_data(ai_setting).merge("changed_fields" => changed_fields_for(ai_setting)),
          actor: resolve_api_actor
        )
        render json: ai_setting.as_json(only: AI_SETTING_FIELDS)
      else
        render json: { error: ai_setting.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      ai_setting = AiSetting.find_by(id: params[:id])
      return render json: { error: "AI setting not found" }, status: :not_found unless ai_setting

      ai_setting.destroy
      if ai_setting.destroyed?
        record_ai_admin_event(
          event_type: "ai_setting_deleted",
          record: ai_setting,
          data: ai_setting_event_data(ai_setting),
          actor: resolve_api_actor
        )
      end

      head :no_content
    end

    private

    def ai_setting_params
      params.require(:ai_setting).permit(:label, :setting_value)
    end
  end
end
