module Api
  class McpsController < Api::BaseController
    MCP_FIELDS = %i[id name transport url authentication status command args created_at updated_at].freeze

    def index
      mcps = Mcp::Server.order(:name, :id)
      render json: {
        count: mcps.count,
        mcps: mcps.map { |mcp| serialize(mcp) }
      }
    end

    def show
      mcp = Mcp::Server.find_by(id: params[:id])
      return render json: { error: "MCP not found" }, status: :not_found unless mcp

      render json: serialize(mcp)
    end

    private

    def serialize(mcp)
      mcp.as_json(only: MCP_FIELDS).merge(
        bearer_token_present: mcp.bearer_token.present?,
        bearer_token_length: mcp.bearer_token.to_s.length,
        environment_present: mcp.environment.present?,
        environment_length: mcp.environment.to_s.length
      )
    end
  end
end
