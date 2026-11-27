module Api
  class AiProfileToolsController < Api::BaseController
    include AiAdminEvents

    AI_PROFILE_TOOL_FIELDS = %i[id ai_profile_id tool_id enabled created_at updated_at].freeze

    before_action :set_profile, only: %i[toggle_enabled]
    before_action :ensure_toolset_editable!, only: %i[toggle_enabled]

    def index
      ai_profile_tools = AiProfileTool.order(:ai_profile_id, :tool_id, :id)
      ai_profile_tools = ai_profile_tools.where(ai_profile_id: params[:ai_profile_id]) if params[:ai_profile_id].present?
      ai_profile_tools = ai_profile_tools.where(tool_id: params[:tool_id]) if params[:tool_id].present?

      render json: {
        count: ai_profile_tools.count,
        ai_profile_tools: ai_profile_tools.as_json(only: AI_PROFILE_TOOL_FIELDS)
      }
    end

    def show
      ai_profile_tool = AiProfileTool.find_by(id: params[:id])
      return render json: { error: "AI profile tool assignment not found" }, status: :not_found unless ai_profile_tool

      render json: ai_profile_tool.as_json(only: AI_PROFILE_TOOL_FIELDS)
    end

    def toggle_enabled
      relation = @profile.ai_profile_tools.find_or_initialize_by(tool_id: params[:tool_id])
      relation.enabled = cast_boolean(params[:enabled])

      if relation.save
        record_ai_admin_event(
          event_type: "ai_profile_tool_updated",
          record: relation,
          data: { "ai_profile_id" => @profile.id, "tool_id" => relation.tool_id, "enabled" => relation.enabled },
          actor: resolve_api_actor
        )
        render json: relation.as_json(only: AI_PROFILE_TOOL_FIELDS)
      else
        render json: { error: relation.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    private

    def set_profile
      @profile = AiProfile.find_by(id: params[:profile_id])
      return render json: { error: "AI profile not found" }, status: :not_found unless @profile
    end

    def ensure_toolset_editable!
      return if @profile.editable? && @profile.tool_sets_editable?

      render json: { error: "profile tool sets not editable" }, status: :forbidden
    end
  end
end
