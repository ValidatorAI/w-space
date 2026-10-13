module Mcp
  module Tools
    module Tasks
      class TasksTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "tasks"
        def description = "List, get, or manage project tasks"
        def aliases = %w[list_tasks Tasks]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              grand_parent_id: { type: %w[string integer] },
              parent_task_id: { type: %w[string integer] },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:task_id].present?
            return success(Task.find(args[:task_id]).as_json)
          end

          scope = Task.all
          scope = scope.where(project_id: args[:project_id]) if args[:project_id].present?
          scope = scope.where(room_id: args[:room_id]) if args[:room_id].present?
          scope = scope.where(parent_task_id: args[:parent_task_id]) if args[:parent_task_id].present?
          scope = scope.where(grand_parent_id: args[:grand_parent_id]) if args[:grand_parent_id].present?
          scope = scope.where(added_to_kanban: boolean_param(args[:added_to_kanban])) if args.key?(:added_to_kanban)
          scope = scope.where(runned: boolean_param(args[:runned])) if args.key?(:runned)

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class GetTaskTool < Mcp::BaseTool
        def name = "get_task"
        def description = "Get a single task by ID"
        def aliases = ["GetTask"]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args) = success(Task.find(args[:task_id]).as_json)
      end

      class CreateTaskTool < Mcp::BaseTool
        def name = "create_task"
        def description = "Create a project task"
        def aliases = ["CreateTask"]

        def input_schema
          {
            type: "object",
            properties: {
              description: { type: "string" },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              parent_task_id: { type: %w[string integer] },
              grand_parent_id: { type: %w[string integer] },
              adder_profile: { type: "string" },
              assigneee_profile: { type: "string" },
              token_used: { type: "integer" },
              usd_used: { type: "number" },
              usd_budget: { type: "number" },
              importance: { type: "integer" },
              level: { type: "integer" }
            },
            required: ["description"]
          }
        end

        def execute(args)
          task = Task.create!(
            description: args[:description],
            project_id: args[:project_id],
            room_id: args[:room_id],
            parent_task_id: args[:parent_task_id],
            grand_parent_id: args[:grand_parent_id],
            adder_profile: args[:adder_profile],
            assigneee_profile: args[:assigneee_profile],
            token_used: args[:token_used],
            usd_used: args[:usd_used],
            usd_budget: args[:usd_budget],
            importance: args[:importance] || 0,
            level: args[:level] || 0
          )
          success(task.as_json)
        end
      end

      class UpdateTaskTool < Mcp::BaseTool
        def name = "update_task"
        def description = "Update a project task"
        def aliases = ["UpdateTask"]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              description: { type: "string" },
              adder_profile: { type: "string" },
              assigneee_profile: { type: "string" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" }
            },
            required: ["task_id"]
          }
        end

        def execute(args)
          task = Task.find(args[:task_id])
          attrs = {
            description: args[:description],
            adder_profile: args[:adder_profile],
            assigneee_profile: args[:assigneee_profile],
            added_to_kanban: args.key?(:added_to_kanban) ? boolean_param(args[:added_to_kanban]) : nil,
            runned: args.key?(:runned) ? boolean_param(args[:runned]) : nil
          }.compact
          task.update!(attrs)
          success(task.as_json)
        end
      end

      class DeleteTaskTool < Mcp::BaseTool
        def name = "delete_task"
        def description = "Delete a project task"
        def aliases = ["DeleteTask"]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args)
          t = Task.find(args[:task_id])
          t.destroy!
          success(status: "deleted", id: t.id)
        end
      end

      # Hierarchy
      class GetTaskChildrenTool < Mcp::BaseTool
        def name = "get_task_children"
        def description = "Get direct children of a task"
        def aliases = %w[get_all_children_tasks GetTaskChildren]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args)
          task = Task.find(args[:task_id])
          success(task.child_tasks.map(&:as_json))
        end
      end

      class GetTaskParentsTool < Mcp::BaseTool
        def name = "get_task_parents"
        def description = "Get parent hierarchy of a task"
        def aliases = %w[get_all_parent_tasks GetTaskParents]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args)
          task = Task.find(args[:task_id])
          parents = []
          curr = task.parent_task
          while curr
            parents << curr.as_json
            curr = curr.parent_task
          end
          success(parents)
        end
      end

      # Task Cost
      class TaskCostTool < Mcp::BaseTool
        def name = "task_cost"
        def description = "Update token and USD costs for a task and roll up to ancestors"
        def aliases = %w[update_task_cost TaskCost]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              token_used: { type: "integer" },
              usd_used: { type: "number" }
            },
            required: ["task_id"]
          }
        end

        def execute(args)
          task = Task.find(args[:task_id])
          task.apply_task_cost!(args[:token_used], args[:usd_used])
          success(task.as_json)
        end
      end
    end
  end
end
