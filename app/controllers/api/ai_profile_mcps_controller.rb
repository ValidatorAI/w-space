module Api
  class AiProfileMcpsController < Api::BaseController
    AI_PROFILE_MCP_FIELDS = %i[id ai_profile_id mcp_id active created_at updated_at].freeze

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
  end
end
