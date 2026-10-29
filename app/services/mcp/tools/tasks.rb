module Mcp
  module Tools
    module Tasks
      class TasksTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "ai_tasks"
        def description = "List, get, or manage AI tasks"
        def aliases = %w[tasks list_ai_tasks list_tasks Tasks]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              grand_parent_id: { type: %w[string integer] },
              parent_task_id: { type: %w[string integer] },
              dispatched: { type: "boolean" },
              finished: { type: "boolean" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:task_id].present?
            return success(AiTask.find(args[:task_id]).as_json)
          end

          scope = AiTask.all
          scope = scope.where(project_id: args[:project_id]) if args[:project_id].present?
          scope = scope.where(room_id: args[:room_id]) if args[:room_id].present?
          scope = scope.where(parent_task_id: args[:parent_task_id]) if args[:parent_task_id].present?
          scope = scope.where(grand_parent_id: args[:grand_parent_id]) if args[:grand_parent_id].present?

          if args.key?(:dispatched) || args.key?(:added_to_kanban)
            dispatched_value = args.key?(:dispatched) ? args[:dispatched] : args[:added_to_kanban]
            scope = scope.where(dispatched: boolean_param(dispatched_value))
          end

          if args.key?(:finished) || args.key?(:runned)
            finished_value = args.key?(:finished) ? args[:finished] : args[:runned]
            scope = scope.where(finished: boolean_param(finished_value))
          end

          items = paginate(scope.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class GetTaskTool < Mcp::BaseTool
        def name = "get_ai_task"
        def description = "Get a single AI task by ID"
        def aliases = %w[get_task GetTask GetAITask]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args) = success(AiTask.find(args[:task_id]).as_json)
      end

      class CreateTaskTool < Mcp::BaseTool
        def name = "create_ai_task"
        def description = "Create a project AI task"
        def aliases = %w[create_task CreateTask CreateAITask]

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
              dispatched: { type: "boolean" },
              finished: { type: "boolean" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" },
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
          task = AiTask.create!(
            description: args[:description],
            project_id: args[:project_id],
            room_id: args[:room_id],
            parent_task_id: args[:parent_task_id],
            grand_parent_id: args[:grand_parent_id],
            adder_profile: args[:adder_profile],
            assigneee_profile: args[:assigneee_profile],
            dispatched: args.key?(:dispatched) ? boolean_param(args[:dispatched]) : (args.key?(:added_to_kanban) ? boolean_param(args[:added_to_kanban]) : false),
            finished: args.key?(:finished) ? boolean_param(args[:finished]) : (args.key?(:runned) ? boolean_param(args[:runned]) : false),
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
        def name = "update_ai_task"
        def description = "Update a project AI task"
        def aliases = %w[update_task UpdateTask UpdateAITask]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              description: { type: "string" },
              adder_profile: { type: "string" },
              assigneee_profile: { type: "string" },
              dispatched: { type: "boolean" },
              finished: { type: "boolean" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" }
            },
            required: ["task_id"]
          }
        end

        def execute(args)
          task = AiTask.find(args[:task_id])
          attrs = {
            description: args[:description],
            adder_profile: args[:adder_profile],
            assigneee_profile: args[:assigneee_profile],
            dispatched: args.key?(:dispatched) ? boolean_param(args[:dispatched]) : (args.key?(:added_to_kanban) ? boolean_param(args[:added_to_kanban]) : nil),
            finished: args.key?(:finished) ? boolean_param(args[:finished]) : (args.key?(:runned) ? boolean_param(args[:runned]) : nil)
          }.compact
          task.update!(attrs)
          success(task.as_json)
        end
      end

      class DeleteTaskTool < Mcp::BaseTool
        def name = "delete_ai_task"
        def description = "Delete a project AI task"
        def aliases = %w[delete_task DeleteTask DeleteAITask]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args)
          t = AiTask.find(args[:task_id])
          t.destroy!
          success(status: "deleted", id: t.id)
        end
      end

      class GetTaskChildrenTool < Mcp::BaseTool
        def name = "get_ai_task_children"
        def description = "Get all descendant children of an AI task (recursively)"
        def aliases = %w[get_task_children get_all_children_tasks GetTaskChildren GetAITaskChildren]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }

        def execute(args)
          task = AiTask.find(args[:task_id])
          descendants = collect_descendants(task)
          success(descendants.map(&:as_json))
        end

        private

        def collect_descendants(task, visited = Set.new)
          return [] if visited.include?(task.id)

          visited << task.id
          task.child_tasks.flat_map do |child|
            [child] + collect_descendants(child, visited)
          end
        end
      end

      class GetTaskParentsTool < Mcp::BaseTool
        def name = "get_ai_task_parents"
        def description = "Get parent hierarchy of an AI task"
        def aliases = %w[get_task_parents get_all_parent_tasks GetTaskParents GetAITaskParents]
        def input_schema = { type: "object", properties: { task_id: { type: %w[string integer] } }, required: ["task_id"] }
        def execute(args)
          task = AiTask.find(args[:task_id])
          parents = []
          curr = task.parent_task
          while curr
            parents << curr.as_json
            curr = curr.parent_task
          end
          success(parents)
        end
      end

      class TaskCostTool < Mcp::BaseTool
        def name = "ai_task_cost"
        def description = "Update token and USD costs for an AI task and roll up to ancestors"
        def aliases = %w[task_cost update_task_cost TaskCost AITaskCost]

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
          task = AiTask.find(args[:task_id])
          task.apply_task_cost!(args[:token_used], args[:usd_used])
          success(task.as_json)
        end
      end
    end
  end
end
