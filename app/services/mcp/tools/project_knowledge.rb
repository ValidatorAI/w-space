module Mcp
  module Tools
    module ProjectKnowledge
      # --- Knowledge Items ---
      class ProjectKnowledgeItemsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_knowledge_items"
        def description = "List, get, or delete project knowledge items"
        def aliases = %w[ProjectKnowledgeItems knowledge_items]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:item_id].present?
            k = ProjectKnowledgeItem.find(args[:item_id])
            if boolean_param(args[:delete])
              k.destroy!
              return success(status: "deleted", id: k.id)
            end
            return success(k.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.knowledge_items.order(position: :asc, created_at: :asc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectKnowledgeItemTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_knowledge_item"
        def description = "Create a project knowledge item"
        def aliases = ["AddProjectKnowledgeItem"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              description: { type: "string" },
              badge: { type: "string" },
              active: { type: "boolean" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          k = project.knowledge_items.create!(
            title: args[:title],
            description: args[:description],
            badge: args[:badge],
            active: args.key?(:active) ? boolean_param(args[:active]) : true
          )
          success(k.as_json)
        end
      end

      class EditProjectKnowledgeItemTool < Mcp::BaseTool
        def name = "edit_project_knowledge_item"
        def description = "Update a project knowledge item"
        def aliases = ["EditProjectKnowledgeItem"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              title: { type: "string" },
              description: { type: "string" },
              badge: { type: "string" },
              active: { type: "boolean" }
            },
            required: ["item_id"]
          }
        end

        def execute(args)
          k = ProjectKnowledgeItem.find(args[:item_id])
          attrs = {
            title: args[:title],
            description: args[:description],
            badge: args[:badge],
            active: args.key?(:active) ? boolean_param(args[:active]) : nil
          }.compact
          k.update!(attrs)
          success(k.as_json)
        end
      end

      class DeleteProjectKnowledgeItemTool < Mcp::BaseTool
        def name = "delete_project_knowledge_item"
        def description = "Delete a project knowledge item"
        def aliases = ["DeleteProjectKnowledgeItem"]
        def input_schema = { type: "object", properties: { item_id: { type: %w[string integer] } }, required: ["item_id"] }

        def execute(args)
          k = ProjectKnowledgeItem.find(args[:item_id])
          k.destroy!
          success(status: "deleted", id: k.id)
        end
      end

      # --- ADRs / Decision Records ---
      class ProjectDecisionRecordsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_decision_records"
        def description = "List, get, or delete project decision records (ADRs)"
        def aliases = %w[project_adrs adrs ProjectDecisionRecord]

        def input_schema
          {
            type: "object",
            properties: {
              adr_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:adr_id].present?
            a = ProjectAdr.find(args[:adr_id])
            if boolean_param(args[:delete])
              a.destroy!
              return success(status: "deleted", id: a.id)
            end
            return success(a.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.adrs.order(position: :asc, created_at: :asc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectDecisionRecordTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_decision_record"
        def description = "Create a project decision record (ADR)"
        def aliases = ["AddProjectDecisionRecord"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              identifier: { type: "string" },
              title: { type: "string" },
              decision_date: { type: "string" },
              status: { type: "string" },
              file_path: { type: "string" }
            },
            required: %w[identifier title]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          a = project.adrs.create!(
            identifier: args[:identifier],
            title: args[:title],
            decision_date: args[:decision_date].present? ? Date.parse(args[:decision_date].to_s) : nil,
            status: args[:status].presence || "proposed",
            file_path: args[:file_path]
          )
          success(a.as_json)
        end
      end

      class EditProjectDecisionRecordTool < Mcp::BaseTool
        def name = "edit_project_decision_record"
        def description = "Update a project decision record (ADR)"
        def aliases = ["EditProjectDecisionRecord"]

        def input_schema
          {
            type: "object",
            properties: {
              adr_id: { type: %w[string integer] },
              identifier: { type: "string" },
              title: { type: "string" },
              decision_date: { type: "string" },
              status: { type: "string" },
              file_path: { type: "string" }
            },
            required: ["adr_id"]
          }
        end

        def execute(args)
          a = ProjectAdr.find(args[:adr_id])
          attrs = {
            identifier: args[:identifier],
            title: args[:title],
            decision_date: args[:decision_date].present? ? Date.parse(args[:decision_date].to_s) : nil,
            status: args[:status],
            file_path: args[:file_path]
          }.compact
          a.update!(attrs)
          success(a.as_json)
        end
      end

      class DeleteProjectDecisionRecordTool < Mcp::BaseTool
        def name = "delete_project_decision_record"
        def description = "Delete a project decision record (ADR)"
        def aliases = ["DeleteProjectDecisionRecord"]
        def input_schema = { type: "object", properties: { adr_id: { type: %w[string integer] } }, required: ["adr_id"] }

        def execute(args)
          a = ProjectAdr.find(args[:adr_id])
          a.destroy!
          success(status: "deleted", id: a.id)
        end
      end

      # --- Project Notes ---
      class ProjectNoteTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "project_note"
        def description = "List, get, or delete project notes"
        def aliases = %w[project_notes ProjectNote]

        def input_schema
          {
            type: "object",
            properties: {
              note_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:note_id].present?
            n = ProjectNote.find(args[:note_id])
            if boolean_param(args[:delete])
              n.destroy!
              return success(status: "deleted", id: n.id)
            end
            return success(n.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.notes.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddProjectNoteTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_project_note"
        def description = "Create a project note"
        def aliases = ["AddProjectNote"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              tags: { type: "string" },
              content: { type: "string" },
              html_source_type: { type: "string" },
              html_source_path: { type: "string" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          n = project.notes.create!(
            title: args[:title],
            tags: args[:tags],
            content: args[:content],
            html_source_type: args[:html_source_type],
            html_source_path: args[:html_source_path]
          )
          success(n.as_json)
        end
      end

      class EditProjectNoteTool < Mcp::BaseTool
        def name = "edit_project_note"
        def description = "Update a project note"
        def aliases = ["EditProjectNote"]

        def input_schema
          {
            type: "object",
            properties: {
              note_id: { type: %w[string integer] },
              title: { type: "string" },
              tags: { type: "string" },
              content: { type: "string" },
              html_source_type: { type: "string" },
              html_source_path: { type: "string" }
            },
            required: ["note_id"]
          }
        end

        def execute(args)
          n = ProjectNote.find(args[:note_id])
          attrs = {
            title: args[:title],
            tags: args[:tags],
            content: args[:content],
            html_source_type: args[:html_source_type],
            html_source_path: args[:html_source_path]
          }.compact
          n.update!(attrs)
          success(n.as_json)
        end
      end

      class DeleteProjectNoteTool < Mcp::BaseTool
        def name = "delete_project_note"
        def description = "Delete a project note"
        def aliases = ["DeleteProjectNote"]
        def input_schema = { type: "object", properties: { note_id: { type: %w[string integer] } }, required: ["note_id"] }

        def execute(args)
          n = ProjectNote.find(args[:note_id])
          n.destroy!
          success(status: "deleted", id: n.id)
        end
      end

      # --- Tree Directory Items ---
      class TreeBasedProjectDirectoryDataTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "tree_based_project_directory_data"
        def description = "List, get, or delete tree-based project directory items"
        def aliases = %w[project_directory_items TreeBasedProjectDirectoryData]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:item_id].present?
            d = ProjectDirectoryItem.find(args[:item_id])
            if boolean_param(args[:delete])
              d.destroy!
              return success(status: "deleted", id: d.id)
            end
            return success(d.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.directory_items.order(position: :asc, created_at: :asc), args)
          success(items.map(&:as_json))
        end
      end

      class AddTreeBasedProjectDirectoryItemTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_tree_based_project_directory_item"
        def description = "Create a tree-based project directory item"
        def aliases = ["AddTreeBasedProjectDirectoryItem"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              name: { type: "string" },
              item_type: { type: "string" },
              file_path: { type: "string" },
              parent_id: { type: %w[string integer] },
              content: { type: "string" }
            },
            required: ["name"]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          d = project.directory_items.create!(
            name: args[:name],
            item_type: args[:item_type].presence || "file",
            file_path: args[:file_path],
            parent_id: args[:parent_id],
            content: args[:content]
          )
          success(d.as_json)
        end
      end

      class EditTreeBasedProjectDirectoryItemTool < Mcp::BaseTool
        def name = "edit_tree_based_project_directory_item"
        def description = "Update a tree-based project directory item"
        def aliases = ["EditTreeBasedProjectDirectoryItem"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              name: { type: "string" },
              item_type: { type: "string" },
              file_path: { type: "string" },
              parent_id: { type: %w[string integer] },
              content: { type: "string" }
            },
            required: ["item_id"]
          }
        end

        def execute(args)
          d = ProjectDirectoryItem.find(args[:item_id])
          attrs = {
            name: args[:name],
            item_type: args[:item_type],
            file_path: args[:file_path],
            parent_id: args[:parent_id],
            content: args[:content]
          }.compact
          d.update!(attrs)
          success(d.as_json)
        end
      end

      class DeleteTreeBasedProjectDirectoryItemTool < Mcp::BaseTool
        def name = "delete_tree_based_project_directory_item"
        def description = "Delete a tree-based project directory item"
        def aliases = ["DeleteTreeBasedProjectDirectoryItem"]
        def input_schema = { type: "object", properties: { item_id: { type: %w[string integer] } }, required: ["item_id"] }

        def execute(args)
          d = ProjectDirectoryItem.find(args[:item_id])
          d.destroy!
          success(status: "deleted", id: d.id)
        end
      end

      # --- External Knowledge Assets ---
      class ExternalKnowledgeAssetsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "external_knowledge_assets"
        def description = "List, get, or delete external knowledge assets"
        def aliases = ["ExternalKnowledgeAssets"]

        def input_schema
          {
            type: "object",
            properties: {
              asset_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:asset_id].present?
            a = ProjectExternalAsset.find(args[:asset_id])
            if boolean_param(args[:delete])
              a.destroy!
              return success(status: "deleted", id: a.id)
            end
            return success(a.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.external_assets.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddExternalKnowledgeAssetTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_external_knowledge_asset"
        def description = "Create an external knowledge asset"
        def aliases = ["AddExternalKnowledgeAsset"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              url: { type: "string" },
              doc_type: { type: "string" },
              icon: { type: "string" },
              source_type: { type: "string" },
              meta_text: { type: "string" }
            },
            required: %w[title url]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          a = project.external_assets.create!(
            title: args[:title],
            url: args[:url],
            doc_type: args[:doc_type],
            icon: args[:icon],
            source_type: args[:source_type].presence || "external_url",
            meta_text: args[:meta_text]
          )
          success(a.as_json)
        end
      end

      class EditExternalKnowledgeAssetTool < Mcp::BaseTool
        def name = "edit_external_knowledge_asset"
        def description = "Update an external knowledge asset"
        def aliases = ["EditExternalKnowledgeAsset"]

        def input_schema
          {
            type: "object",
            properties: {
              asset_id: { type: %w[string integer] },
              title: { type: "string" },
              url: { type: "string" },
              doc_type: { type: "string" },
              icon: { type: "string" },
              source_type: { type: "string" },
              meta_text: { type: "string" }
            },
            required: ["asset_id"]
          }
        end

        def execute(args)
          a = ProjectExternalAsset.find(args[:asset_id])
          attrs = {
            title: args[:title],
            url: args[:url],
            doc_type: args[:doc_type],
            icon: args[:icon],
            source_type: args[:source_type],
            meta_text: args[:meta_text]
          }.compact
          a.update!(attrs)
          success(a.as_json)
        end
      end

      class DeleteExternalKnowledgeAssetTool < Mcp::BaseTool
        def name = "delete_external_knowledge_asset"
        def description = "Delete an external knowledge asset"
        def aliases = ["DeleteExternalKnowledgeAsset"]
        def input_schema = { type: "object", properties: { asset_id: { type: %w[string integer] } }, required: ["asset_id"] }

        def execute(args)
          a = ProjectExternalAsset.find(args[:asset_id])
          a.destroy!
          success(status: "deleted", id: a.id)
        end
      end

      # --- Knowledge Activity Log ---
      class KnowledgeActivityLogTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "knowledge_activity_log"
        def description = "List, get, or delete knowledge activity log entries"
        def aliases = ["KnowledgeActivityLog"]

        def input_schema
          {
            type: "object",
            properties: {
              activity_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:activity_id].present?
            a = ProjectKnowledgeActivity.find(args[:activity_id])
            if boolean_param(args[:delete])
              a.destroy!
              return success(status: "deleted", id: a.id)
            end
            return success(a.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.knowledge_activities.order(created_at: :desc), args)
          success(items.map(&:as_json))
        end
      end

      class AddKnowledgeActivityLogTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_knowledge_activity_log"
        def description = "Create a knowledge activity log entry"
        def aliases = ["AddKnowledgeActivityLog"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              actor_name: { type: "string" },
              action_text: { type: "string" },
              actor_color: { type: "string" },
              target_path: { type: "string" },
              target_url: { type: "string" }
            },
            required: %w[actor_name action_text]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          a = project.knowledge_activities.create!(
            actor_name: args[:actor_name],
            action_text: args[:action_text],
            actor_color: args[:actor_color],
            target_path: args[:target_path],
            target_url: args[:target_url]
          )
          success(a.as_json)
        end
      end

      class EditKnowledgeActivityLogTool < Mcp::BaseTool
        def name = "edit_knowledge_activity_log"
        def description = "Update a knowledge activity log entry"
        def aliases = ["EditKnowledgeActivityLog"]

        def input_schema
          {
            type: "object",
            properties: {
              activity_id: { type: %w[string integer] },
              actor_name: { type: "string" },
              action_text: { type: "string" },
              actor_color: { type: "string" },
              target_path: { type: "string" },
              target_url: { type: "string" }
            },
            required: ["activity_id"]
          }
        end

        def execute(args)
          a = ProjectKnowledgeActivity.find(args[:activity_id])
          attrs = {
            actor_name: args[:actor_name],
            action_text: args[:action_text],
            actor_color: args[:actor_color],
            target_path: args[:target_path],
            target_url: args[:target_url]
          }.compact
          a.update!(attrs)
          success(a.as_json)
        end
      end

      class DeleteKnowledgeActivityLogTool < Mcp::BaseTool
        def name = "delete_knowledge_activity_log"
        def description = "Delete a knowledge activity log entry"
        def aliases = ["DeleteKnowledgeActivityLog"]
        def input_schema = { type: "object", properties: { activity_id: { type: %w[string integer] } }, required: ["activity_id"] }

        def execute(args)
          a = ProjectKnowledgeActivity.find(args[:activity_id])
          a.destroy!
          success(status: "deleted", id: a.id)
        end
      end

      # --- Knowledge Summary Items (mapped to ProjectKnowledgeItem) ---
      class KnowledgeSummaryItemsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "knowledge_summary_items"
        def description = "List, get, or delete knowledge summary items"
        def aliases = ["KnowledgeSummaryItems"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:item_id].present?
            k = ProjectKnowledgeItem.find(args[:item_id])
            if boolean_param(args[:delete])
              k.destroy!
              return success(status: "deleted", id: k.id)
            end
            return success(k.as_json)
          end

          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          items = paginate(project.knowledge_items.order(position: :asc, created_at: :asc), args)
          success(items.map(&:as_json))
        end
      end

      class AddKnowledgeSummaryItemTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "add_knowledge_summary_item"
        def description = "Create a knowledge summary item"
        def aliases = ["AddKnowledgeSummaryItem"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              title: { type: "string" },
              description: { type: "string" },
              badge: { type: "string" }
            },
            required: %w[title description]
          }
        end

        def execute(args)
          project = resolve_project(args) || Project.first
          return failure("Project not found") unless project

          k = project.knowledge_items.create!(
            title: args[:title],
            description: args[:description],
            badge: args[:badge]
          )
          success(k.as_json)
        end
      end

      class EditKnowledgeSummaryItemTool < Mcp::BaseTool
        def name = "edit_knowledge_summary_item"
        def description = "Update a knowledge summary item"
        def aliases = ["EditKnowledgeSummaryItem"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer] },
              title: { type: "string" },
              description: { type: "string" },
              badge: { type: "string" }
            },
            required: ["item_id"]
          }
        end

        def execute(args)
          k = ProjectKnowledgeItem.find(args[:item_id])
          attrs = { title: args[:title], description: args[:description], badge: args[:badge] }.compact
          k.update!(attrs)
          success(k.as_json)
        end
      end

      class DeleteKnowledgeSummaryItemTool < Mcp::BaseTool
        def name = "delete_knowledge_summary_item"
        def description = "Delete a knowledge summary item"
        def aliases = ["DeleteKnowledgeSummaryItem"]
        def input_schema = { type: "object", properties: { item_id: { type: %w[string integer] } }, required: ["item_id"] }

        def execute(args)
          k = ProjectKnowledgeItem.find(args[:item_id])
          k.destroy!
          success(status: "deleted", id: k.id)
        end
      end
    end
  end
end
