module Mcp
  module Tools
    module ProjectItems
      # --- Milestones ---
      class ProjectMilestonesTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_milestones"
        def description = "List, get, or delete project milestones"
        def aliases = ["ProjectMilestones"]

        def input_schema
          {
            type: "object",
            properties: {
              milestone_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:milestone_id].present?
            m = ProjectMilestone.find(args[:milestone_id])
            if boolean_param(args[:delete])
              m.destroy!
              return success(status: "deleted", id: m.id)
            end
            return success(m.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          scope = project.milestones.order(position: :asc, created_at: :asc)
          items = paginate(scope, args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectMilestoneTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_milestone"
        def description = "Create a project milestone"
        def aliases = ["AddProjectMilestone"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              target_date: { type: "string" },
              status: { type: "string" },
              active: { type: "boolean" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          milestone = project.milestones.create!(
            title: args[:title],
            target_date: args[:target_date].present? ? Date.parse(args[:target_date].to_s) : nil,
            status: args[:status].presence || "planned",
            active: args.key?(:active) ? boolean_param(args[:active]) : true
          )
          success(milestone.as_json)
        end
      end

      class EditProjectMilestoneTool < Mcp::BaseTool
        def name = "edit_project_milestone"
        def description = "Update a project milestone"
        def aliases = ["EditProjectMilestone"]

        def input_schema
          {
            type: "object",
            properties: {
              milestone_id: { type: %w[string integer] },
              title: { type: "string" },
              target_date: { type: "string" },
              status: { type: "string" },
              active: { type: "boolean" }
            },
            required: ["milestone_id"]
          }
        end

        def execute(args)
          m = ProjectMilestone.find(args[:milestone_id])
          attrs = {
            title: args[:title],
            target_date: args[:target_date].present? ? Date.parse(args[:target_date].to_s) : nil,
            status: args[:status],
            active: args.key?(:active) ? boolean_param(args[:active]) : nil
          }.compact
          m.update!(attrs)
          success(m.as_json)
        end
      end

      class DeleteProjectMilestoneTool < Mcp::BaseTool
        def name = "delete_project_milestone"
        def description = "Delete a project milestone"
        def aliases = ["DeleteProjectMilestone"]
        def input_schema = { type: "object", properties: { milestone_id: { type: %w[string integer] } }, required: ["milestone_id"] }

        def execute(args)
          m = ProjectMilestone.find(args[:milestone_id])
          m.destroy!
          success(status: "deleted", id: m.id)
        end
      end

      # --- Bottlenecks ---
      class ProjectBottlenecksTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_bottlenecks"
        def description = "List, get, or delete project bottlenecks"
        def aliases = ["ProjectBottlenecks"]

        def input_schema
          {
            type: "object",
            properties: {
              bottleneck_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:bottleneck_id].present?
            b = ProjectBottleneck.find(args[:bottleneck_id])
            if boolean_param(args[:delete])
              b.destroy!
              return success(status: "deleted", id: b.id)
            end
            return success(b.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.bottlenecks.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectBottleneckTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_bottleneck"
        def description = "Create a project bottleneck"
        def aliases = ["AddProjectBottleneck"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              description: { type: "string" },
              severity: { type: "string" },
              resolved: { type: "boolean" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          b = project.bottlenecks.create!(
            title: args[:title],
            description: args[:description],
            severity: args[:severity].presence || "medium",
            resolved: boolean_param(args[:resolved]) || false
          )
          success(b.as_json)
        end
      end

      class EditProjectBottleneckTool < Mcp::BaseTool
        def name = "edit_project_bottleneck"
        def description = "Update a project bottleneck"
        def aliases = ["EditProjectBottleneck"]

        def input_schema
          {
            type: "object",
            properties: {
              bottleneck_id: { type: %w[string integer] },
              title: { type: "string" },
              description: { type: "string" },
              severity: { type: "string" },
              resolved: { type: "boolean" }
            },
            required: ["bottleneck_id"]
          }
        end

        def execute(args)
          b = ProjectBottleneck.find(args[:bottleneck_id])
          attrs = {
            title: args[:title],
            description: args[:description],
            severity: args[:severity],
            resolved: args.key?(:resolved) ? boolean_param(args[:resolved]) : nil,
            resolved_at: boolean_param(args[:resolved]) ? Time.current : nil
          }.compact
          b.update!(attrs)
          success(b.as_json)
        end
      end

      class DeleteProjectBottleneckTool < Mcp::BaseTool
        def name = "delete_project_bottleneck"
        def description = "Delete a project bottleneck"
        def aliases = ["DeleteProjectBottleneck"]
        def input_schema = { type: "object", properties: { bottleneck_id: { type: %w[string integer] } }, required: ["bottleneck_id"] }

        def execute(args)
          b = ProjectBottleneck.find(args[:bottleneck_id])
          b.destroy!
          success(status: "deleted", id: b.id)
        end
      end

      # --- Todos ---
      class ProjectTodosTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_todos"
        def description = "List, get, or delete project todos"
        def aliases = ["ProjectTodos"]

        def input_schema
          {
            type: "object",
            properties: {
              todo_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:todo_id].present?
            t = ProjectTodo.find(args[:todo_id])
            if boolean_param(args[:delete])
              t.destroy!
              return success(status: "deleted", id: t.id)
            end
            return success(t.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.todos.order(position: :asc, created_at: :asc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectTodoTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_todo"
        def description = "Create a project todo"
        def aliases = ["AddProjectTodo"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              completed: { type: "boolean" },
              meta_text: { type: "string" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          todo = project.todos.create!(
            title: args[:title],
            completed: boolean_param(args[:completed]) || false,
            meta_text: args[:meta_text]
          )
          success(todo.as_json)
        end
      end

      class EditProjectTodoTool < Mcp::BaseTool
        def name = "edit_project_todo"
        def description = "Update a project todo"
        def aliases = ["EditProjectTodo"]

        def input_schema
          {
            type: "object",
            properties: {
              todo_id: { type: %w[string integer] },
              title: { type: "string" },
              completed: { type: "boolean" },
              meta_text: { type: "string" }
            },
            required: ["todo_id"]
          }
        end

        def execute(args)
          todo = ProjectTodo.find(args[:todo_id])
          attrs = {
            title: args[:title],
            completed: args.key?(:completed) ? boolean_param(args[:completed]) : nil,
            meta_text: args[:meta_text]
          }.compact
          todo.update!(attrs)
          success(todo.as_json)
        end
      end

      class DeleteProjectTodoTool < Mcp::BaseTool
        def name = "delete_project_todo"
        def description = "Delete a project todo"
        def aliases = ["DeleteProjectTodo"]
        def input_schema = { type: "object", properties: { todo_id: { type: %w[string integer] } }, required: ["todo_id"] }

        def execute(args)
          todo = ProjectTodo.find(args[:todo_id])
          todo.destroy!
          success(status: "deleted", id: todo.id)
        end
      end
    end
  end
end
