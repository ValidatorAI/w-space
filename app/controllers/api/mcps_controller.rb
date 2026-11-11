module Api
  class McpsController < Api::BaseController
    include AiAdminEvents

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

    def create
      mcp = Mcp::Server.new(mcp_params)
      if mcp.save
        record_ai_admin_event(
          event_type: "mcp_created",
          record: mcp,
          data: mcp_event_data(mcp),
          actor: resolve_api_actor
        )
        render json: serialize(mcp), status: :created
      else
        render json: { error: mcp.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def update
      mcp = Mcp::Server.find_by(id: params[:id])
      return render json: { error: "MCP not found" }, status: :not_found unless mcp

      if mcp.update(mcp_params)
        record_ai_admin_event(
          event_type: "mcp_updated",
          record: mcp,
          data: mcp_event_data(mcp).merge("changed_fields" => changed_fields_for(mcp)),
          actor: resolve_api_actor
        )
        render json: serialize(mcp)
      else
        render json: { error: mcp.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      mcp = Mcp::Server.find_by(id: params[:id])
      return render json: { error: "MCP not found" }, status: :not_found unless mcp

      mcp.destroy
      if mcp.destroyed?
        record_ai_admin_event(
          event_type: "mcp_deleted",
          record: mcp,
          data: mcp_event_data(mcp),
          actor: resolve_api_actor
        )
      end

      head :no_content
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

    def mcp_params
      params.require(:mcp).permit(:name, :transport, :url, :authentication, :bearer_token, :status, :command, :args, :environment)
    end
  end
end
