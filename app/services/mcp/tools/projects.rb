module Mcp
  module Tools
    module Projects
      class AddProjectTool < Mcp::BaseTool
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

          project = Project.new(attrs)
          unless project.save
            return failure(project.errors.full_messages.to_sentence)
          end

          OutputEvents::Recorder.record(
            event_type: "project_created",
            event_id: project.id,
            group_id: SecureRandom.uuid,
            actor: nil,
            target_type: "Project",
            data: { "slug" => project.slug, "path" => project.path, "member_user_ids" => [] }
          )

          success(project.public_mcp_attributes.merge("created" => true))
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

          project.assign_attributes(attrs)
          unless project.save
            return failure(project.errors.full_messages.to_sentence)
          end

          if project.previous_changes.except("updated_at").any?
            OutputEvents::Recorder.record(
              event_type: "project_updated",
              event_id: project.id,
              group_id: SecureRandom.uuid,
              actor: nil,
              target_type: "Project",
              data: { "changed_fields" => project.previous_changes.except("updated_at").keys.map(&:to_s) }
            )
          end

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

          pending_count = ApprovalRequest.joins(:room).where(rooms: { project_id: project.id }, status: :pending).count
          return failure("open approvals exist: #{pending_count}") if pending_count.positive?

          project.destroy!
          OutputEvents::Recorder.record(
            event_type: "project_deleted",
            event_id: project.id,
            actor: nil,
            target_type: "Project",
            data: {}
          )

          success(status: "deleted", id: project.id)
        end
      end
    end
  end
end
