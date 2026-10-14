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
              message_analysis_id: { type: %w[string integer] },
              analysis_id: { type: %w[string integer] },
              message_id: { type: %w[string integer] },
              importance_level: { type: "integer" },
              is_a_response: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          target_id = args[:message_analysis_id].presence || args[:analysis_id].presence || args[:id]
          if target_id.present?
            return success(MessageAnalysis.find(target_id).as_json)
          end

          scope = MessageAnalysis.all
          scope = scope.where(message_id: args[:message_id]) if args[:message_id].present?
          scope = scope.where(importance_level: args[:importance_level]) if args[:importance_level].present?
          scope = scope.where(is_a_response: boolean_param(args[:is_a_response])) if args.key?(:is_a_response)

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class GetMessageAnalysisTool < Mcp::BaseTool
        def name = "get_message_analysis"
        def description = "Fetch a single message analysis record by ID"
        def aliases = ["GetMessageAnalysis"]
        def input_schema = { type: "object", properties: { message_analysis_id: { type: %w[string integer] }, analysis_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_analysis_id].presence || args[:analysis_id].presence || args[:id]
          raise ArgumentError, "message_analysis_id is required" if target_id.blank?
          success(MessageAnalysis.find(target_id).as_json)
        end
      end

      class CreateMessageAnalysisTool < Mcp::BaseTool
        def name = "create_message_analysis"
        def description = "Create a message analysis record"
        def aliases = ["CreateMessageAnalysis"]

        def input_schema
          {
            type: "object",
            properties: {
              message_id: { type: %w[string integer] },
              importance_level: { type: "integer" },
              message_content_summary: { type: "string" },
              message_type: { type: "string" },
              tags: { type: "string" },
              is_a_response: { type: "boolean" },
              analysis: { type: "string" }
            },
            required: ["message_id"]
          }
        end

        def execute(args)
          summary = args[:message_content_summary].presence || args[:analysis].presence || "Message Analysis"
          importance = args[:importance_level].presence || 3
          msg_type = args[:message_type].presence || "analysis"
          is_resp = args.key?(:is_a_response) ? boolean_param(args[:is_a_response]) : false

          ma = MessageAnalysis.create!(
            message_id: args[:message_id],
            importance_level: importance,
            message_content_summary: summary,
            message_type: msg_type,
            tags: args[:tags],
            is_a_response: is_resp
          )
          success(ma.as_json)
        end
      end

      class UpdateMessageAnalysisTool < Mcp::BaseTool
        def name = "update_message_analysis"
        def description = "Update a message analysis record"
        def aliases = ["UpdateMessageAnalysis"]

        def input_schema
          {
            type: "object",
            properties: {
              message_analysis_id: { type: %w[string integer] },
              analysis_id: { type: %w[string integer] },
              id: { type: %w[string integer] },
              importance_level: { type: "integer" },
              message_content_summary: { type: "string" },
              message_type: { type: "string" },
              tags: { type: "string" },
              is_a_response: { type: "boolean" },
              analysis: { type: "string" }
            }
          }
        end

        def execute(args)
          target_id = args[:message_analysis_id].presence || args[:analysis_id].presence || args[:id]
          raise ArgumentError, "message_analysis_id is required" if target_id.blank?

          ma = MessageAnalysis.find(target_id)
          summary = args[:message_content_summary].presence || args[:analysis]
          attrs = {
            importance_level: args[:importance_level],
            message_content_summary: summary,
            message_type: args[:message_type],
            tags: args[:tags],
            is_a_response: args.key?(:is_a_response) ? boolean_param(args[:is_a_response]) : nil
          }.compact
          ma.update!(attrs)
          success(ma.as_json)
        end
      end

      class DeleteMessageAnalysisTool < Mcp::BaseTool
        def name = "delete_message_analysis"
        def description = "Delete a message analysis record"
        def aliases = ["DeleteMessageAnalysis"]
        def input_schema = { type: "object", properties: { message_analysis_id: { type: %w[string integer] }, analysis_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_analysis_id].presence || args[:analysis_id].presence || args[:id]
          raise ArgumentError, "message_analysis_id is required" if target_id.blank?

          ma = MessageAnalysis.find(target_id)
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
        def input_schema = { type: "object", properties: { message_topic_id: { type: %w[string integer] }, topic_id: { type: %w[string integer] }, message_id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_topic_id].presence || args[:id]
          if target_id.present?
            return success(MessageTopic.find(target_id).as_json)
          end

          scope = MessageTopic.all
          scope = scope.where(message_id: args[:message_id]) if args[:message_id].present?
          scope = scope.where(topic_id: args[:topic_id]) if args[:topic_id].present?
          success(paginate(scope.order(created_at: :desc), args).map(&:as_json))
        end
      end

      class GetMessageTopicTool < Mcp::BaseTool
        def name = "get_message_topic"
        def description = "Fetch a single message topic link by ID"
        def aliases = ["GetMessageTopic"]
        def input_schema = { type: "object", properties: { message_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_topic_id].presence || args[:id]
          raise ArgumentError, "message_topic_id is required" if target_id.blank?
          success(MessageTopic.find(target_id).as_json)
        end
      end

      class CreateMessageTopicTool < Mcp::BaseTool
        def name = "create_message_topic"
        def description = "Assign topic to message"
        def aliases = ["CreateMessageTopic"]
        def input_schema = { type: "object", properties: { message_id: { type: %w[string integer] }, topic_id: { type: %w[string integer] }, created_date: { type: "string" } }, required: %w[message_id topic_id] }

        def execute(args)
          c_date = args[:created_date].present? ? Time.zone.parse(args[:created_date].to_s) : Time.current
          success(MessageTopic.create!(message_id: args[:message_id], topic_id: args[:topic_id], created_date: c_date).as_json)
        end
      end

      class UpdateMessageTopicTool < Mcp::BaseTool
        def name = "update_message_topic"
        def description = "Update a message topic link"
        def aliases = ["UpdateMessageTopic"]
        def input_schema = { type: "object", properties: { message_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] }, topic_id: { type: %w[string integer] }, message_id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_topic_id].presence || args[:id]
          raise ArgumentError, "message_topic_id is required" if target_id.blank?

          mt = MessageTopic.find(target_id)
          attrs = { topic_id: args[:topic_id], message_id: args[:message_id] }.compact
          mt.update!(attrs)
          success(mt.as_json)
        end
      end

      class DeleteMessageTopicTool < Mcp::BaseTool
        def name = "delete_message_topic"
        def description = "Remove topic from message"
        def aliases = ["DeleteMessageTopic"]
        def input_schema = { type: "object", properties: { message_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:message_topic_id].presence || args[:id]
          raise ArgumentError, "message_topic_id is required" if target_id.blank?

          mt = MessageTopic.find(target_id)
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
        def input_schema = { type: "object", properties: { room_history_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] }, room_id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:room_history_topic_id].presence || args[:id]
          if target_id.present?
            return success(RoomHistoryTopic.find(target_id).as_json)
          end

          scope = RoomHistoryTopic.all
          scope = scope.where(room_id: args[:room_id]) if args[:room_id].present?
          success(paginate(scope.order(created_at: :desc), args).map(&:as_json))
        end
      end

      class GetRoomHistoryTopicTool < Mcp::BaseTool
        def name = "get_room_history_topic"
        def description = "Fetch a single room history topic snapshot by ID"
        def aliases = ["GetRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { room_history_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:room_history_topic_id].presence || args[:id]
          raise ArgumentError, "room_history_topic_id is required" if target_id.blank?
          success(RoomHistoryTopic.find(target_id).as_json)
        end
      end

      class CreateRoomHistoryTopicTool < Mcp::BaseTool
        def name = "create_room_history_topic"
        def description = "Create room history topic"
        def aliases = ["CreateRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { room_id: { type: %w[string integer] }, last_state: { type: "string" }, created_date: { type: "string" } }, required: ["room_id"] }

        def execute(args)
          c_date = args[:created_date].present? ? Time.zone.parse(args[:created_date].to_s) : Time.current
          success(RoomHistoryTopic.create!(room_id: args[:room_id], last_state: args[:last_state], created_date: c_date).as_json)
        end
      end

      class UpdateRoomHistoryTopicTool < Mcp::BaseTool
        def name = "update_room_history_topic"
        def description = "Update room history topic"
        def aliases = ["UpdateRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { room_history_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] }, last_state: { type: "string" } } }

        def execute(args)
          target_id = args[:room_history_topic_id].presence || args[:id]
          raise ArgumentError, "room_history_topic_id is required" if target_id.blank?

          rht = RoomHistoryTopic.find(target_id)
          rht.update!(last_state: args[:last_state])
          success(rht.as_json)
        end
      end

      class DeleteRoomHistoryTopicTool < Mcp::BaseTool
        def name = "delete_room_history_topic"
        def description = "Delete room history topic"
        def aliases = ["DeleteRoomHistoryTopic"]
        def input_schema = { type: "object", properties: { room_history_topic_id: { type: %w[string integer] }, id: { type: %w[string integer] } } }

        def execute(args)
          target_id = args[:room_history_topic_id].presence || args[:id]
          raise ArgumentError, "room_history_topic_id is required" if target_id.blank?

          rht = RoomHistoryTopic.find(target_id)
          rht.destroy!
          success(status: "deleted", id: rht.id)
        end
      end
    end
  end
end
