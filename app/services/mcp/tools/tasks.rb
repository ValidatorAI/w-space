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
              topic_id: { type: %w[string integer] },
              input_event_entity_id: { type: %w[string integer] },
              proposed_task_context: { type: "string" },
              actual_task_context: { type: "string" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:task_id].present?
            return success(AiTask.find(args[:task_id]).as_json)
          end

          project = args[:project_id].present? ? resolve_project(args) : nil
          raise ArgumentError, "Project not found for project_id=#{args[:project_id].inspect}" if args[:project_id].present? && project.nil?

          room = args[:room_id].present? ? resolve_room(args, project: project) : nil
          raise ArgumentError, "Room not found for room_id=#{args[:room_id].inspect}" if args[:room_id].present? && room.nil?

          scope = AiTask.all
          scope = scope.where(project_id: project.id) if project.present?
          scope = scope.where(room_id: room.id) if room.present?
          scope = scope.where(parent_task_id: args[:parent_task_id]) if args[:parent_task_id].present?
          scope = scope.where(grand_parent_id: args[:grand_parent_id]) if args[:grand_parent_id].present?
          scope = scope.where(topic_id: args[:topic_id]) if args[:topic_id].present?
          scope = scope.where(task_id: args[:task_id]) if args[:task_id].present?
          scope = scope.where(input_event_entity_id: args[:input_event_entity_id]) if args[:input_event_entity_id].present?
          scope = scope.where(proposed_task_context: args[:proposed_task_context]) if args[:proposed_task_context].present?
          scope = scope.where(actual_task_context: args[:actual_task_context]) if args[:actual_task_context].present?

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
        include Mcp::Tools::Concerns::ResolutionHelpers

        VALID_KEYS = %w[
          description project_id room_id parent_task_id grand_parent_id task_id
          input_event_entity_id adder_profile assigneee_profile assignee_profile
          proposed_task_context dispatched finished added_to_kanban runned
          topic_id token_used usd_used usd_budget importance level
        ].freeze

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
              task_id: { type: %w[string integer] },
              input_event_entity_id: { type: %w[string integer] },
              adder_profile: { type: "string" },
              assigneee_profile: { type: "string" },
              assignee_profile: { type: "string" },
              proposed_task_context: { type: "string" },
              dispatched: { type: "boolean" },
              finished: { type: "boolean" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" },
              topic_id: { type: %w[string integer] },
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
          validate_allowed_keys!(args, VALID_KEYS)
          assignee_profile = args[:assigneee_profile].presence || args[:assignee_profile].presence

          project = resolve_task_project(args)
          room = resolve_task_room(args, project: project)

          task = AiTask.create!(
            task_id: args[:task_id].presence,
            input_event_entity_id: args[:input_event_entity_id].presence,
            description: args[:description],
            project_id: project&.id,
            room_id: room&.id,
            parent_task_id: args[:parent_task_id].presence,
            grand_parent_id: args[:grand_parent_id].presence,
            adder_profile: args[:adder_profile],
            assigneee_profile: assignee_profile,
            proposed_task_context: args[:proposed_task_context].presence,
            actual_task_context: nil,
            dispatched: args.key?(:dispatched) ? boolean_param(args[:dispatched]) : (args.key?(:added_to_kanban) ? boolean_param(args[:added_to_kanban]) : false),
            finished: args.key?(:finished) ? boolean_param(args[:finished]) : (args.key?(:runned) ? boolean_param(args[:runned]) : false),
            topic_id: args[:topic_id].presence,
            token_used: args[:token_used],
            usd_used: args[:usd_used],
            usd_budget: args[:usd_budget],
            importance: args[:importance] || 0,
            level: args[:level] || 0
          )

          result = task.as_json
          if assignee_profile.blank?
            result["warning"] = missing_assignee_warning(task)
          end
          success(result)
        end

        private

        def resolve_task_project(args)
          return nil if args[:project_id].blank?

          project = resolve_project(args)
          raise ArgumentError, "Project not found for project_id=#{args[:project_id].inspect}" if project.nil?

          project
        end

        def resolve_task_room(args, project: nil)
          return nil if args[:room_id].blank?

          room = resolve_room(args, project: project)
          raise ArgumentError, "Room not found for room_id=#{args[:room_id].inspect}" if room.nil?

          room
        end

        def validate_allowed_keys!(args, allowed_keys)
          unexpected = args.keys.map(&:to_s) - allowed_keys.map(&:to_s)
          return if unexpected.empty?

          raise ArgumentError, "Unknown argument(s): #{unexpected.sort.join(', ')}. Allowed keys: #{allowed_keys.sort.join(', ')}"
        end

        def missing_assignee_warning(task)
          project = task.project
          attention_item = nil

          if project.present?
            attention_item = project.attention_items.create!(
              category: "blockers",
              title: "AI task missing assignee profile: #{task.description.to_s.truncate(80)}",
              meta_text: "Task #{task.id} was created without an assignee profile and will not dispatch until a profile is assigned.",
              status: "pending"
            )
          end

          {
            code: "missing_assignee_profile",
            message: "Task was created without an assignee profile and will not dispatch until a profile is assigned.",
            attention_item: {
              id: attention_item&.id,
              category: "blockers",
              project_id: project&.id,
              title: attention_item&.title || "AI task missing assignee profile",
              status: attention_item&.status || "pending"
            }.compact
          }
        end
      end

      class UpdateTaskTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        VALID_KEYS = %w[
          task_id description project_id room_id adder_profile assigneee_profile assignee_profile
          input_event_entity_id actual_task_context dispatched finished added_to_kanban
          runned topic_id
        ].freeze

        def name = "update_ai_task"
        def description = "Update a project AI task"
        def aliases = %w[update_task UpdateTask UpdateAITask]

        def input_schema
          {
            type: "object",
            properties: {
              task_id: { type: %w[string integer] },
              description: { type: "string" },
              project_id: { type: %w[string integer] },
              room_id: { type: %w[string integer] },
              adder_profile: { type: "string" },
              assigneee_profile: { type: "string" },
              assignee_profile: { type: "string" },
              input_event_entity_id: { type: %w[string integer] },
              actual_task_context: { type: "string" },
              dispatched: { type: "boolean" },
              finished: { type: "boolean" },
              added_to_kanban: { type: "boolean" },
              runned: { type: "boolean" },
              topic_id: { type: %w[string integer] }
            },
            required: ["task_id"]
          }
        end

        def execute(args)
          validate_allowed_keys!(args, VALID_KEYS)
          task = AiTask.find(args[:task_id])
          attrs = {}

          project = args[:project_id].present? ? resolve_project(args) : nil
          if args[:project_id].present? && project.nil?
            raise ArgumentError, "Project not found for project_id=#{args[:project_id].inspect}"
          end

          room = args[:room_id].present? ? resolve_room(args, project: project || task.project) : nil
          if args[:room_id].present? && room.nil?
            raise ArgumentError, "Room not found for room_id=#{args[:room_id].inspect}"
          end

          attrs[:description] = args[:description] if args.key?(:description)
          attrs[:adder_profile] = args[:adder_profile] if args.key?(:adder_profile)
          assignee_profile = args[:assigneee_profile].presence || args[:assignee_profile].presence
          attrs[:assigneee_profile] = assignee_profile if assignee_profile.present? || args.key?(:assigneee_profile) || args.key?(:assignee_profile)
          attrs[:task_id] = args[:task_id].presence if args.key?(:task_id) && args[:task_id].to_i != task.id.to_i
          attrs[:input_event_entity_id] = args[:input_event_entity_id].presence if args.key?(:input_event_entity_id)
          attrs[:actual_task_context] = args[:actual_task_context].presence if args.key?(:actual_task_context)
          attrs[:proposed_task_context] = nil
          attrs[:project_id] = project.id if project.present?
          attrs[:room_id] = room.id if room.present?

          if args.key?(:dispatched) || args.key?(:added_to_kanban)
            attrs[:dispatched] = args.key?(:dispatched) ? boolean_param(args[:dispatched]) : boolean_param(args[:added_to_kanban])
          end

          if args.key?(:finished) || args.key?(:runned)
            attrs[:finished] = args.key?(:finished) ? boolean_param(args[:finished]) : boolean_param(args[:runned])
          end

          attrs[:topic_id] = args[:topic_id].presence if args.key?(:topic_id)

          task.update!(attrs)
          success(task.as_json)
        end

        private

        def validate_allowed_keys!(args, allowed_keys)
          unexpected = args.keys.map(&:to_s) - allowed_keys.map(&:to_s)
          return if unexpected.empty?

          raise ArgumentError, "Unknown argument(s): #{unexpected.sort.join(', ')}. Allowed keys: #{allowed_keys.sort.join(', ')}"
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
