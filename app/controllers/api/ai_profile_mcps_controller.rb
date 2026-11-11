module Api
  class AiProfileMcpsController < Api::BaseController
    include AiAdminEvents

    AI_PROFILE_MCP_FIELDS = %i[id ai_profile_id mcp_id active created_at updated_at].freeze

    before_action :set_profile, only: %i[toggle_enabled]
    before_action :ensure_toolset_editable!, only: %i[toggle_enabled]

    def index
      ai_profile_mcps = AiProfileMcp.order(:ai_profile_id, :mcp_id, :id)
      ai_profile_mcps = ai_profile_mcps.where(ai_profile_id: params[:ai_profile_id]) if params[:ai_profile_id].present?
      ai_profile_mcps = ai_profile_mcps.where(mcp_id: params[:mcp_id]) if params[:mcp_id].present?

      render json: {
        count: ai_profile_mcps.count,
        ai_profile_mcps: ai_profile_mcps.as_json(only: AI_PROFILE_MCP_FIELDS)
      }
    end

    def show
      ai_profile_mcp = AiProfileMcp.find_by(id: params[:id])
      return render json: { error: "AI profile MCP assignment not found" }, status: :not_found unless ai_profile_mcp

      render json: ai_profile_mcp.as_json(only: AI_PROFILE_MCP_FIELDS)
    end

    def toggle_enabled
      relation = @profile.ai_profile_mcps.find_or_initialize_by(mcp_id: params[:mcp_id])
      relation.active = cast_boolean(params[:active])

      if relation.save
        record_ai_admin_event(
          event_type: "ai_profile_mcp_updated",
          record: relation,
          data: { "ai_profile_id" => @profile.id, "mcp_id" => relation.mcp_id, "active" => relation.active },
          actor: resolve_api_actor
        )
        render json: relation.as_json(only: AI_PROFILE_MCP_FIELDS)
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
