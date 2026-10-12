module Mcp
  module Identity
    class ListBotsTool < Mcp::BaseTool
      description "List chat bots"

      schema(
        properties: {
          include_deactivated: { type: "boolean", description: "Include deactivated bots" }
        },
        required: []
      )

      class << self
        def call(params)
          agent = current_agent(params)
          return error_response("Not authenticated", code: "unauthorized") unless agent

          include_deactivated = params[:include_deactivated] == true

          bots = if include_deactivated
            User.where(role: :bot)
          else
            User.active_bots
          end

          success_response({
            bots: bots.ordered.map { |bot| serialize_bot(bot) },
            total: bots.count
          })
        end

        private

        def serialize_bot(bot)
          {
            id: bot.id,
            name: bot.name,
            email_address: bot.email_address,
            status: bot.status,
            created_at: bot.created_at&.iso8601,
            updated_at: bot.updated_at&.iso8601
          }
        end
      end
    end
  end
end