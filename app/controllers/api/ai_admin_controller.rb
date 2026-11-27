module Api
  class AiAdminController < Api::BaseController
    def restart_w_bridge
      command = "hermes gateway restart"
      triggered = system(command)
      return render json: { triggered: true }, status: :ok if triggered

      render json: { triggered: false }, status: :internal_server_error
    end

    def reset_ai_config
      begin
        summary = AiConfig::ResetFromXml.call
      rescue AiConfig::XmlLoader::ConfigError, ActiveRecord::RecordInvalid, KeyError => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end

      OutputEvents::Recorder.record(
        event_type: "ai_config_reset",
        actor: resolve_api_actor,
        target_type: "AiConfig",
        data: {
          "source_path" => AiConfig::XmlLoader::SOURCE_PATH.relative_path_from(Rails.root).to_s,
          "summary" => summary
        }
      )

      render json: { status: "ok", summary: summary }
    end
  end
end
