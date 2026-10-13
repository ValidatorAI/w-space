module Mcp
  module Tools
    module Messaging
      LOADING_PREFIX = ":spin:"

      # --- Rooms ---
      class ListRoomsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "list_rooms"
        def description = "List all chat rooms in the workspace"
        def aliases = %w[rooms ListRooms]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          scope = Room.all
          project = resolve_project(args)
          scope = scope.where(project_id: project.id) if project

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class SearchRoomsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "search_rooms"
        def description = "Search chat rooms by name or query"
        def aliases = ["SearchRooms"]

        def input_schema
          {
            type: "object",
            properties: {
              query: { type: "string", description: "Search query string" },
              project_id: { type: %w[string integer] },
              page: { type: "integer" },
              per_page: { type: "integer" }
            },
            required: ["query"]
          }
        end

        def execute(args)
          q = args[:query].to_s.strip
          scope = Room.where("LOWER(name) LIKE ?", "%#{q.downcase}%")
          if args[:project_id].present?
            scope = scope.where(project_id: args[:project_id])
          end

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      # --- Messages ---
      class AddMessageTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_message"
        def description = "Add a message to a room"
        def aliases = ["AddMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              bot_id: { type: %w[string integer] },
              bot_name: { type: "string" },
              body: { type: "string", description: "Message body text" }
            },
            required: ["body"]
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project) || Room.first
          return failure("Room not found") unless room

          sender = resolve_sender(args, project: project)
          return failure("Sender (user or bot) not found") unless sender

          message = room.messages.create!(
            body: args[:body],
            creator: sender,
            client_message_id: SecureRandom.uuid
          )
          message.broadcast_create

          success(
            id: message.id,
            room_id: room.id,
            creator_id: sender.id,
            creator_type: sender.class.name,
            body: message.plain_text_body,
            created_at: message.created_at
          )
        end
      end

      class DeleteMessageTool < Mcp::BaseTool
        def name = "delete_message"
        def description = "Delete a message from a room"
        def aliases = ["DeleteMessage"]
        def input_schema = { type: "object", properties: { message_id: { type: %w[string integer] } }, required: ["message_id"] }

        def execute(args)
          msg = Message.find(args[:message_id])
          msg.destroy!
          msg.broadcast_remove
          success(status: "deleted", id: msg.id)
        end
      end

      # --- Ephemeral Loading Messages ---
      class AddLoadingMessageTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_loading_message"
        def description = "Add a loading/thinking message to a room (auto-prefixed with :spin:)"
        def aliases = ["AddLoadingMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              bot_id: { type: %w[string integer] },
              bot_name: { type: "string" },
              body: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project) || Room.first
          return failure("Room not found") unless room

          sender = resolve_sender(args, project: project)
          body_text = "#{LOADING_PREFIX} #{args[:body]}".strip

          msg = room.messages.create!(
            body: body_text,
            creator: sender,
            client_message_id: SecureRandom.uuid
          )
          msg.broadcast_create

          success(id: msg.id, room_id: room.id, body: msg.plain_text_body)
        end
      end

      class EditLoadingMessageTool < Mcp::BaseTool
        def name = "edit_loading_message"
        def description = "Edit an existing loading message in a room"
        def aliases = ["EditLoadingMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              message_id: { type: %w[string integer] },
              body: { type: "string" }
            },
            required: ["message_id"]
          }
        end

        def execute(args)
          msg = Message.find(args[:message_id])
          body_text = "#{LOADING_PREFIX} #{args[:body]}".strip
          msg.update!(body: body_text)
          msg.broadcast_replace_to msg.room, :messages, target: [msg, :presentation], partial: "messages/presentation", attributes: { maintain_scroll: true }

          success(id: msg.id, body: msg.plain_text_body)
        end
      end

      class DeleteLoadingMessageTool < Mcp::BaseTool
        def name = "delete_loading_message"
        def description = "Delete a loading message from a room"
        def aliases = ["DeleteLoadingMessage"]
        def input_schema = { type: "object", properties: { message_id: { type: %w[string integer] } }, required: ["message_id"] }

        def execute(args)
          msg = Message.find(args[:message_id])
          msg.destroy!
          msg.broadcast_remove
          success(status: "deleted", id: msg.id)
        end
      end

      # --- Action & Decision Messages ---
      class AddActionMessageTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_action_message"
        def description = "Send a real-time action (e.g. typing indicator) to a room"
        def aliases = ["AddActionMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              action_type: { type: "string", description: "Action type (e.g. typing_start, typing_stop)" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project) || Room.first
          return failure("Room not found") unless room

          sender = resolve_sender(args, project: project)
          action_type = args[:action_type].presence || "typing_start"

          # Broadcast action state to ActionCable
          room.broadcast_action_state(sender, action: action_type) if room.respond_to?(:broadcast_action_state)

          success(status: "broadcasted", room_id: room.id, action_type: action_type)
        end
      end

      class AddDecisionMessageTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_decision_message"
        def description = "Record a decision on an approval request in a room"
        def aliases = ["AddDecisionMessage"]

        def input_schema
          {
            type: "object",
            properties: {
              approval_request_id: { type: %w[string integer] },
              decision: { type: "string", description: "Decision: approve, confirm, deny, cancel" },
              note: { type: "string" }
            },
            required: %w[approval_request_id decision]
          }
        end

        def execute(args)
          req = ApprovalRequest.find(args[:approval_request_id])
          decision = args[:decision].to_s.downcase

          case decision
          when "approve" then req.approve!(User.first, note: args[:note])
          when "confirm" then req.confirm!(User.first, note: args[:note])
          when "deny"    then req.deny!(User.first, note: args[:note])
          when "cancel"  then req.cancel!(User.first, note: args[:note])
          else
            return failure("Unknown decision: #{decision}. Expected: approve, confirm, deny, cancel")
          end

          req.broadcast_replacement if req.respond_to?(:broadcast_replacement)
          success(req.as_json)
        end
      end
    end
  end
end
