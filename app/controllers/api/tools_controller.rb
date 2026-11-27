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

    def toggle
      tool = Tool.find_by(id: params[:id])
      return render json: { error: "Tool not found" }, status: :not_found unless tool

      if tool.update(active: cast_boolean(params[:active]))
        render json: tool.as_json(only: TOOL_FIELDS)
      else
        render json: { error: tool.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end
  end
end
