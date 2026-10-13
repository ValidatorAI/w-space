module Mcp
  module Tools
    module Topics
      # --- Topics ---
      class TopicsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "topics"
        def description = "List, get, or manage knowledge topics"
        def aliases = %w[list_topics Topics]

        def input_schema
          {
            type: "object",
            properties: {
              topic_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              active: { type: "boolean" },
              need_an_action: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:topic_id].present?
            return success(Topic.find(args[:topic_id]).as_json)
          end

          scope = Topic.all
          scope = scope.where(project_id: args[:project_id]) if args[:project_id].present?
          scope = scope.where(room_id: args[:room_id]) if args[:room_id].present?
          scope = scope.where(active: boolean_param(args[:active])) if args.key?(:active)
          scope = scope.where(need_an_action: boolean_param(args[:need_an_action])) if args.key?(:need_an_action)

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class GetTopicTool < Mcp::BaseTool
        def name = "get_topic"
        def description = "Get a single knowledge topic"
        def aliases = ["GetTopic"]
        def input_schema = { type: "object", properties: { topic_id: { type: %w[string integer] } }, required: ["topic_id"] }
        def execute(args) = success(Topic.find(args[:topic_id]).as_json)
      end

      class CreateTopicTool < Mcp::BaseTool
        def name = "create_topic"
        def description = "Create a new knowledge topic"
        def aliases = ["CreateTopic"]

        def input_schema
          {
            type: "object",
            properties: {
              name: { type: "string" },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              memory: { type: "string" },
              state: { type: "string" },
              active: { type: "boolean" },
              need_an_action: { type: "boolean" }
            },
            required: ["name"]
          }
        end

        def execute(args)
          t = Topic.create!(
            name: args[:name],
            project_id: args[:project_id],
            room_id: args[:room_id],
            memory: args[:memory],
            state: args[:state],
            active: args.key?(:active) ? boolean_param(args[:active]) : true,
            need_an_action: boolean_param(args[:need_an_action]) || false
          )
          success(t.as_json)
        end
      end

      class UpdateTopicTool < Mcp::BaseTool
        def name = "update_topic"
        def description = "Update a knowledge topic"
        def aliases = ["UpdateTopic"]

        def input_schema
          {
            type: "object",
            properties: {
              topic_id: { type: %w[string integer] },
              name: { type: "string" },
              memory: { type: "string" },
              state: { type: "string" },
              active: { type: "boolean" },
              need_an_action: { type: "boolean" }
            },
            required: ["topic_id"]
          }
        end

        def execute(args)
          t = Topic.find(args[:topic_id])
          attrs = {
            name: args[:name],
            memory: args[:memory],
            state: args[:state],
            active: args.key?(:active) ? boolean_param(args[:active]) : nil,
            need_an_action: args.key?(:need_an_action) ? boolean_param(args[:need_an_action]) : nil
          }.compact
          t.update!(attrs)
          success(t.as_json)
        end
      end

      class DeleteTopicTool < Mcp::BaseTool
        def name = "delete_topic"
        def description = "Delete a knowledge topic"
        def aliases = ["DeleteTopic"]
        def input_schema = { type: "object", properties: { topic_id: { type: %w[string integer] } }, required: ["topic_id"] }
        def execute(args)
          t = Topic.find(args[:topic_id])
          t.destroy!
          success(status: "deleted", id: t.id)
        end
      end

      # --- Message Analysis ---
      class MessageAnalysisTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "message_analysis"
        def description = "List or get message analysis records"
        def aliases = %w[list_message_analysis MessageAnalysis]

        def input_schema
          {
            type: "object",
            properties: {
              analysis_id: { type: %w[string integer] },
              message_id: { type: %w[string integer] },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:analysis_id].present?
            return success(MessageAnalysis.find(args[:analysis_id]).as_json)
          end

          scope = MessageAnalysis.all
          scope = scope.where(message_id: args[:message_id]) if args[:message_id].present?
          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class CreateMessageAnalysisTool < Mcp::BaseTool
        def name = "create_message_analysis"
        def description = "Create a message analysis record"
        def aliases = ["CreateMessageAnalysis"]
        def input_schema = { type: "object", properties: { message_id: { type: %w[string integer] }, analysis: { type: "string" } }, required: ["message_id"] }
        def execute(args)
          ma = MessageAnalysis.create!(message_id: args[:message_id], analysis: args[:analysis])
          success(ma.as_json)
        end
      end

      class UpdateMessageAnalysisTool < Mcp::BaseTool
        def name = "update_message_analysis"
        def description = "Update a message analysis record"
        def aliases = ["UpdateMessageAnalysis"]
        def input_schema = { type: "object", properties: { analysis_id: { type: %w[string integer] }, analysis: { type: "string" } }, required: ["analysis_id"] }
        def execute(args)
          ma = MessageAnalysis.find(args[:analysis_id])
          ma.update!(analysis: args[:analysis])
          success(ma.as_json)
        end
      end

      class DeleteMessageAnalysisTool < Mcp::BaseTool
        def name = "delete_message_analysis"
        def description = "Delete a message analysis record"
        def aliases = ["DeleteMessageAnalysis"]
        def input_schema = { type: "object", properties: { analysis_id: { type: %w[string integer] } }, required: ["analysis_id"] }
        def execute(args)
          ma = MessageAnalysis.find(args[:analysis_id])
          ma.destroy!
          success(status: "deleted", id: ma.id)
        end
      end

      # --- Message Topics ---
      class MessageTopicsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "message_topics"
        def description = "List or get message topics"
        def aliases = %w[list_message_topics MessageTopics]
        def input_schema = { type: "object", properties: { topic_id: { type: %w[string integer] }, message_id: { type: %w[string integer] } } }
        def execute(args)
          scope = MessageTopic.all
          scope = scope.where(message_id: args[:message_id]) if args[:message_id].present?
          scope = scope.where(topic_id: args[:topic_id]) if args[:topic_id].present?
          success(paginate(scope.order(created_at: :desc), args).map(&:as_json))
        end
      end

      class CreateMessageTopicTool < Mcp::BaseTool
        def name = "create_message_topic"
        def description = "Assign topic to message"
        def aliases = ["CreateMessageTopic"]
        def input_schema = { type: "object", properties: { message_id: { type: %w[string integer] }, topic_id: { type: %w[string integer] } }, required: %w[message_id topic_id] }
        def execute(args) = success(MessageTopic.create!(message_id: args[:message_id], topic_id: args[:topic_id]).as_json)
      end

      class DeleteMessageTopicTool < Mcp::BaseTool
        def name = "delete_message_topic"
        def description = "Remove topic from message"
        def aliases = ["DeleteMessageTopic"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] } }, required: ["id"] }
        def execute(args)
          mt = MessageTopic.find(args[:id])
          mt.destroy!
          success(status: "deleted", id: mt.id)
        end
      end

      # --- Room History Topics ---
      class RoomHistoryTopicsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "room_history_topics"
        def description = "List or get room history topics"
        def aliases = %w[list_room_history_topics RoomHistoryTopics room_history]
        def input_schema = { type: "object", properties: { room_id: { type: %w[string integer] } } }
        def execute(args)
          scope = RoomHistoryTopic.all
          scope = scope.where(room_id: args[:room_id]) if args[:room_id].present?
          success(paginate(scope.order(created_at: :desc), args).map(&:as_json))
        end
      end

      class CreateRoomHistoryTopicTool < Mcp::BaseTool
        def name = "create_room_history_topic"
        def description = "Create room history topic"
        def aliases = ["CreateRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { room_id: { type: %w[string integer] }, last_state: { type: "string" } }, required: ["room_id"] }
        def execute(args) = success(RoomHistoryTopic.create!(room_id: args[:room_id], last_state: args[:last_state]).as_json)
      end

      class UpdateRoomHistoryTopicTool < Mcp::BaseTool
        def name = "update_room_history_topic"
        def description = "Update room history topic"
        def aliases = ["UpdateRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] }, last_state: { type: "string" } }, required: ["id"] }
        def execute(args)
          rht = RoomHistoryTopic.find(args[:id])
          rht.update!(last_state: args[:last_state])
          success(rht.as_json)
        end
      end

      class DeleteRoomHistoryTopicTool < Mcp::BaseTool
        def name = "delete_room_history_topic"
        def description = "Delete room history topic"
        def aliases = ["DeleteRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] } }, required: ["id"] }
        def execute(args)
          rht = RoomHistoryTopic.find(args[:id])
          rht.destroy!
          success(status: "deleted", id: rht.id)
        end
      end
    end
  end
end
