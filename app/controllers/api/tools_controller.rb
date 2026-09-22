module Api
  class ToolsController < Api::BaseController
    TOOL_FIELDS = %i[id name active created_at updated_at].freeze

    def index
      tools = Tool.order(:name, :id)
      render json: {
        count: tools.count,
        tools: tools.as_json(only: TOOL_FIELDS)
      }
    end

    def show
      tool = Tool.find_by(id: params[:id])
      return render json: { error: "Tool not found" }, status: :not_found unless tool

      render json: tool.as_json(only: TOOL_FIELDS)
    end
  end
end
