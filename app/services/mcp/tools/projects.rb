module Mcp
  module Tools
    module Projects
      class AddProjectTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project"
        def description = "Create a project"
        def aliases = ["AddProject"]

        def input_schema
          {
            type: "object",
            properties: {
              path: { type: "string", description: "Unique project path" },
              name: { type: "string", description: "Project display name" },
              description: { type: "string" },
              private: { type: "boolean" },
              short_code: { type: "string" },
              user_name: { type: "string", description: "Optional actor name" },
              actor_user_id: { type: %w[string integer], description: "Optional actor user id" }
            },
            required: ["path"]
          }
        end

        def execute(args)
          path = args[:path].presence
          return failure("Path is required") if path.blank?

          existing = Project.find_by(path: path)
          if existing
            return success(existing.public_mcp_attributes.merge("created" => false))
          end

          attrs = {
            path: path,
            name: args[:name].presence,
            description: args[:description].presence,
            private: args.key?(:private) ? boolean_param(args[:private]) : false,
            short_code: args[:short_code].presence
          }.compact

          actor = resolve_user(args)
          result = ProjectAdminService.create(attributes: attrs, actor: actor)
          project = result[:project]

          success(project.public_mcp_attributes.merge("created" => result[:created]))
        end
      end

      class EditProjectTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "edit_project"
        def description = "Update a project"
        def aliases = ["EditProject"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              name: { type: "string" },
              path: { type: "string" },
              description: { type: "string" },
              private: { type: "boolean" },
              short_code: { type: "string" },
              current_phase: { type: "string" },
              roadmap: { type: "string" },
              recently_completed: { type: "string" },
              budget_total: { type: %w[string integer number] },
              budget_spent: { type: %w[string integer number] }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          return failure("Project not found") unless project

          attrs = {}
          %i[name path description private short_code current_phase roadmap recently_completed budget_total budget_spent].each do |field|
            next if args[field].nil?

            attrs[field] = case field
                           when :private
                             boolean_param(args[field])
                           else
                             args[field]
                           end
          end

          return success(project.public_mcp_attributes.merge("changed_fields" => [])) if attrs.empty?

          actor = resolve_user(args)
          project = ProjectAdminService.update(project: project, attributes: attrs, actor: actor)

          changed_fields = project.previous_changes.except("updated_at").keys.map(&:to_s)
          success(project.public_mcp_attributes.merge("changed_fields" => changed_fields))
        end
      end

      class DeleteProjectTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "delete_project"
        def description = "Delete a project"
        def aliases = ["DeleteProject"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          return failure("Project not found") unless project

          pending_count = ProjectAdminService.pending_approvals_count(project)
          return failure("open approvals exist: #{pending_count}") if pending_count.positive?

          ProjectAdminService.destroy(project, actor: resolve_user(args))
          success(status: "deleted", id: project.id)
        end
      end
    end
  end
end
