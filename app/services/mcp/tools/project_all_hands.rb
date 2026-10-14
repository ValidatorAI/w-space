module Mcp
  module Tools
    module ProjectAllHands
      # --- Takeaways ---
      class ProjectAllHandsTakeawayTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_all_hands_takeaway"
        def description = "List, get, or delete project all-hands takeaways"
        def aliases = %w[project_all_hands_takeaways ProjectAllHandsTakeaway ProjectAllHandsTakeaways]

        def input_schema
          {
            type: "object",
            properties: {
              takeaway_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:takeaway_id].present?
            t = ProjectAllHandsTakeaway.find(args[:takeaway_id])
            if boolean_param(args[:delete])
              t.destroy!
              return success(status: "deleted", id: t.id)
            end
            return success(t.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.all_hands_takeaways.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectAllHandsTakeawayTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_all_hands_takeaway"
        def description = "Create a project all-hands takeaway"
        def aliases = ["AddProjectAllHandsTakeaway"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              text: { type: "string" },
              tag: { type: "string" }
            },
            required: ["text"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          t = project.all_hands_takeaways.create!(
            text: args[:text],
            tag: args[:tag]
          )
          success(t.as_json)
        end
      end

      class EditProjectAllHandsTakeawayTool < Mcp::BaseTool
        def name = "edit_project_all_hands_takeaway"
        def description = "Update a project all-hands takeaway"
        def aliases = ["EditProjectAllHandsTakeaway"]

        def input_schema
          {
            type: "object",
            properties: {
              takeaway_id: { type: %w[string integer] },
              text: { type: "string" },
              tag: { type: "string" }
            },
            required: ["takeaway_id"]
          }
        end

        def execute(args)
          t = ProjectAllHandsTakeaway.find(args[:takeaway_id])
          attrs = { text: args[:text], tag: args[:tag] }.compact
          t.update!(attrs)
          success(t.as_json)
        end
      end

      class DeleteProjectAllHandsTakeawayTool < Mcp::BaseTool
        def name = "delete_project_all_hands_takeaway"
        def description = "Delete a project all-hands takeaway"
        def aliases = ["DeleteProjectAllHandsTakeaway"]
        def input_schema = { type: "object", properties: { takeaway_id: { type: %w[string integer] } }, required: ["takeaway_id"] }

        def execute(args)
          t = ProjectAllHandsTakeaway.find(args[:takeaway_id])
          t.destroy!
          success(status: "deleted", id: t.id)
        end
      end

      # --- Decisions ---
      class ProjectAllHandsDecisionTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_all_hands_decision"
        def description = "List, get, or delete project all-hands decisions"
        def aliases = %w[project_all_hands_decisions ProjectAllHandsDecision ProjectAllHandsDecisions]

        def input_schema
          {
            type: "object",
            properties: {
              decision_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:decision_id].present?
            d = ProjectAllHandsDecision.find(args[:decision_id])
            if boolean_param(args[:delete])
              d.destroy!
              return success(status: "deleted", id: d.id)
            end
            return success(d.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.all_hands_decisions.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectAllHandsDecisionTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_all_hands_decision"
        def description = "Create a project all-hands decision"
        def aliases = ["AddProjectAllHandsDecision"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              text: { type: "string" },
              badge: { type: "string" },
              basis: { type: "string" },
              impact: { type: "string" }
            },
            required: ["text"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          d = project.all_hands_decisions.create!(
            text: args[:text],
            badge: args[:badge],
            basis: args[:basis],
            impact: args[:impact]
          )
          success(d.as_json)
        end
      end

      class EditProjectAllHandsDecisionTool < Mcp::BaseTool
        def name = "edit_project_all_hands_decision"
        def description = "Update a project all-hands decision"
        def aliases = ["EditProjectAllHandsDecision"]

        def input_schema
          {
            type: "object",
            properties: {
              decision_id: { type: %w[string integer] },
              text: { type: "string" },
              badge: { type: "string" },
              basis: { type: "string" },
              impact: { type: "string" }
            },
            required: ["decision_id"]
          }
        end

        def execute(args)
          d = ProjectAllHandsDecision.find(args[:decision_id])
          attrs = {
            text: args[:text],
            badge: args[:badge],
            basis: args[:basis],
            impact: args[:impact]
          }.compact
          d.update!(attrs)
          success(d.as_json)
        end
      end

      class DeleteProjectAllHandsDecisionTool < Mcp::BaseTool
        def name = "delete_project_all_hands_decision"
        def description = "Delete a project all-hands decision"
        def aliases = ["DeleteProjectAllHandsDecision"]
        def input_schema = { type: "object", properties: { decision_id: { type: %w[string integer] } }, required: ["decision_id"] }

        def execute(args)
          d = ProjectAllHandsDecision.find(args[:decision_id])
          d.destroy!
          success(status: "deleted", id: d.id)
        end
      end

      # --- Action Items ---
      class ProjectAllHandsActionItemTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_all_hands_action_item"
        def description = "List, get, or delete project all-hands action items"
        def aliases = %w[project_all_hands_action_items ProjectAllHandsActionItem ProjectAllHandsActionItems]

        def input_schema
          {
            type: "object",
            properties: {
              action_item_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:action_item_id].present?
            a = ProjectAllHandsActionItem.find(args[:action_item_id])
            if boolean_param(args[:delete])
              a.destroy!
              return success(status: "deleted", id: a.id)
            end
            return success(a.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.all_hands_action_items.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectAllHandsActionItemTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_all_hands_action_item"
        def description = "Create a project all-hands action item"
        def aliases = ["AddProjectAllHandsActionItem"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              assignee_name: { type: "string" },
              due_date: { type: "string" },
              completed: { type: "boolean" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          a = project.all_hands_action_items.create!(
            title: args[:title],
            assignee_name: args[:assignee_name],
            due_date: args[:due_date].present? ? Date.parse(args[:due_date].to_s) : nil,
            completed: boolean_param(args[:completed]) || false
          )
          success(a.as_json)
        end
      end

      class EditProjectAllHandsActionItemTool < Mcp::BaseTool
        def name = "edit_project_all_hands_action_item"
        def description = "Update a project all-hands action item"
        def aliases = ["EditProjectAllHandsActionItem"]

        def input_schema
          {
            type: "object",
            properties: {
              action_item_id: { type: %w[string integer] },
              title: { type: "string" },
              assignee_name: { type: "string" },
              due_date: { type: "string" },
              completed: { type: "boolean" }
            },
            required: ["action_item_id"]
          }
        end

        def execute(args)
          a = ProjectAllHandsActionItem.find(args[:action_item_id])
          attrs = {
            title: args[:title],
            assignee_name: args[:assignee_name],
            due_date: args[:due_date].present? ? Date.parse(args[:due_date].to_s) : nil,
            completed: args.key?(:completed) ? boolean_param(args[:completed]) : nil
          }.compact
          a.update!(attrs)
          success(a.as_json)
        end
      end

      class DeleteProjectAllHandsActionItemTool < Mcp::BaseTool
        def name = "delete_project_all_hands_action_item"
        def description = "Delete a project all-hands action item"
        def aliases = ["DeleteProjectAllHandsActionItem"]
        def input_schema = { type: "object", properties: { action_item_id: { type: %w[string integer] } }, required: ["action_item_id"] }

        def execute(args)
          a = ProjectAllHandsActionItem.find(args[:action_item_id])
          a.destroy!
          success(status: "deleted", id: a.id)
        end
      end
    end
  end
end
