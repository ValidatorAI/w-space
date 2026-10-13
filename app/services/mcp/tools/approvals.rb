module Mcp
  module Tools
    module Approvals
      class ApprovalRequestsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "approval_requests"
        def description = "List, get, or manage approval requests"
        def aliases = ["ApprovalRequests"]

        def input_schema
          {
            type: "object",
            properties: {
              request_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              status: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:request_id].present?
            req = ApprovalRequest.find(args[:request_id])
            if boolean_param(args[:delete])
              req.destroy!
              return success(status: "deleted", id: req.id)
            end
            return success(req.as_json)
          end

          scope = ApprovalRequest.all
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          scope = scope.where(room_id: room.id) if room
          scope = scope.where(status: args[:status]) if args[:status].present?

          items = paginate(scope.recent, args)
          success(items.map(&:as_json))
        end
      end

      class GetApprovalRequestTool < Mcp::BaseTool
        def name = "get_approval_request"
        def description = "Get a single approval request"
        def aliases = ["GetApprovalRequest"]
        def input_schema = { type: "object", properties: { request_id: { type: %w[string integer] } }, required: ["request_id"] }

        def execute(args)
          req = ApprovalRequest.find(args[:request_id])
          success(req.as_json)
        end
      end

      class AddApprovalRequestTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_approval_request"
        def description = "Create an approval request in a room"
        def aliases = ["AddApprovalRequest"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              message_id: { type: %w[string integer] },
              request_type: { type: "string" },
              payload: { type: "object" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project) || Room.first
          return failure("Room not found") unless room

          req = room.approval_requests.create!(
            request_type: args[:request_type].presence || "action",
            payload: args[:payload] || {},
            message_id: args[:message_id],
            status: "pending"
          )
          req.broadcast_replacement if req.respond_to?(:broadcast_replacement)
          success(req.as_json)
        end
      end

      class AddApproveRequestWithMessageTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_approve_request_with_message"
        def description = "Create a message in a room and attach an approval request to it"
        def aliases = ["AddApproveRequestWithMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              body: { type: "string" },
              request_type: { type: "string" },
              payload: { type: "object" }
            },
            required: ["body"]
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project) || Room.first
          return failure("Room not found") unless room

          sender = resolve_sender(args, project: project)

          message = room.messages.create!(
            body: args[:body],
            creator: sender,
            client_message_id: SecureRandom.uuid
          )
          message.broadcast_create

          req = room.approval_requests.create!(
            message: message,
            request_type: args[:request_type].presence || "action",
            payload: args[:payload] || {},
            status: "pending"
          )

          success(message: message.as_json, approval_request: req.as_json)
        end
      end

      class EditApprovalRequestTool < Mcp::BaseTool
        def name = "edit_approval_request"
        def description = "Update an approval request"
        def aliases = ["EditApprovalRequest"]

        def input_schema
          {
            type: "object",
            properties: {
              request_id: { type: %w[string integer] },
              status: { type: "string" },
              payload: { type: "object" }
            },
            required: ["request_id"]
          }
        end

        def execute(args)
          req = ApprovalRequest.find(args[:request_id])
          attrs = {
            status: args[:status],
            payload: args[:payload]
          }.compact
          req.update!(attrs)
          req.broadcast_replacement if req.respond_to?(:broadcast_replacement)
          success(req.as_json)
        end
      end

      class DeleteApprovalRequestTool < Mcp::BaseTool
        def name = "delete_approval_request"
        def description = "Delete an approval request"
        def aliases = ["DeleteApprovalRequest"]
        def input_schema = { type: "object", properties: { request_id: { type: %w[string integer] } }, required: ["request_id"] }

        def execute(args)
          req = ApprovalRequest.find(args[:request_id])
          req.destroy!
          success(status: "deleted", id: req.id)
        end
      end
    end
  end
end
