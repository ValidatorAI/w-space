module Api
  class AiProfileToolsController < Api::BaseController
    AI_PROFILE_TOOL_FIELDS = %i[id ai_profile_id tool_id enabled created_at updated_at].freeze

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
  end
end
