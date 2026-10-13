module Mcp
  module Tools
    module AttentionItems
      class AttentionItemsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "attention_items"
        def description = "List, get, or manage attention items across projects and users"
        def aliases = ["AttentionItems"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer], description: "Attention item ID for get or delete" },
              category: { type: "string", description: "Category filter or setting" },
              status: { type: "string", description: "Status filter or setting (pending, resolved, dismissed)" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              delete: { type: "boolean", description: "Set to true to delete item by item_id" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          if args[:item_id].present?
            item = AttentionItem.find(args[:item_id])
            if boolean_param(args[:delete])
              item.destroy!
              return success(status: "deleted", id: item.id)
            end
            return success(item.as_json)
          end

          scope = AttentionItem.all
          scope = scope.where(category: args[:category]) if args[:category].present?
          scope = scope.where(status: args[:status]) if args[:status].present?

          project = resolve_project(args)
          scope = scope.where(project_id: project.id) if project

          user = resolve_user(args, project: project)
          scope = scope.where(user_id: user.id) if user

          items = paginate(scope.ordered, args)
          success(items.map(&:as_json))
        end
      end

      # Generic category tool that handles list / add / update / delete for a category
      class CategoryBaseTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def self.category_name
          @category_name
        end

        def self.for_category(cat)
          @category_name = cat
        end

        def name
          self.class.category_name
        end

        def description
          "List, get, create, update, or delete #{name} attention items"
        end

        def aliases
          [name.camelize]
        end

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer], description: "Item ID for get/edit/delete" },
              title: { type: "string", description: "Title of the item" },
              meta_text: { type: "string" },
              status: { type: "string", description: "Status (pending, resolved, dismissed)" },
              action_label: { type: "string" },
              ai_confirm: { type: "boolean" },
              due_at: { type: "string" },
              overdue: { type: "boolean" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          cat = self.class.category_name

          if args[:item_id].present?
            item = AttentionItem.find(args[:item_id])
            if boolean_param(args[:delete])
              item.destroy!
              return success(status: "deleted", id: item.id)
            end

            # Edit if attributes provided
            if args[:title].present? || args[:status].present? || args[:meta_text].present? || args.key?(:ai_confirm)
              project = resolve_project(args)
              room = resolve_room(args, project: project)
              user = resolve_user(args, project: project)

              attrs = {
                title: args[:title],
                meta_text: args[:meta_text],
                status: args[:status],
                action_label: args[:action_label],
                ai_confirm: boolean_param(args[:ai_confirm]),
                overdue: boolean_param(args[:overdue]),
                due_at: args[:due_at].present? ? Time.zone.parse(args[:due_at].to_s) : nil,
                project: project,
                room: room,
                user: user
              }.compact

              item.update!(attrs)
            end

            return success(item.as_json)
          end

          # Create if title is provided
          if args[:title].present?
            project = resolve_project(args)
            room = resolve_room(args, project: project)
            user = resolve_user(args, project: project)

            item = AttentionItem.create!(
              category: cat,
              title: args[:title],
              meta_text: args[:meta_text],
              status: args[:status].presence || "pending",
              action_label: args[:action_label],
              ai_confirm: boolean_param(args[:ai_confirm]) || (cat == "ai_confirm"),
              overdue: boolean_param(args[:overdue]) || false,
              due_at: args[:due_at].present? ? Time.zone.parse(args[:due_at].to_s) : nil,
              project: project,
              room: room,
              user: user
            )
            return success(item.as_json)
          end

          # Otherwise List
          scope = AttentionItem.where(category: cat)
          scope = scope.where(status: args[:status]) if args[:status].present?
          project = resolve_project(args)
          scope = scope.where(project_id: project.id) if project

          items = paginate(scope.ordered, args)
          success(items.map(&:as_json))
        end
      end

      # Category tools
      class DecisionsWaitingTool < CategoryBaseTool; for_category "decisions_waiting"; end
      class BlockersTool < CategoryBaseTool; for_category "blockers"; end
      class OutcomesReviewTool < CategoryBaseTool; for_category "outcomes_review"; end
      class MentionsTool < CategoryBaseTool; for_category "mentions"; end
      class MaterialChangesTool < CategoryBaseTool; for_category "material_changes"; end
      class AiConfirmTool < CategoryBaseTool; for_category "ai_confirm"; end
      class KnowledgeProposalsTool < CategoryBaseTool; for_category "knowledge_proposals"; end

      # Add action tools
      class AddAttentionItemBase < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def self.category_name
          @category_name
        end
        def self.for_category(cat)
          @category_name = cat
        end

        def name = "add_#{self.class.category_name}"
        def description = "Create a company-home #{self.class.category_name} attention item"
        def aliases = ["Add#{self.class.category_name.camelize}"]

        def input_schema
          {
            type: "object",
            properties: {
              title: { type: "string", description: "Title of the item" },
              meta_text: { type: "string" },
              action_label: { type: "string" },
              due_at: { type: "string" },
              overdue: { type: "boolean" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" }
            },
            required: ["title"]
          }
        end

        def execute(args)
          cat = self.class.category_name
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          user = resolve_user(args, project: project)

          item = AttentionItem.create!(
            category: cat,
            title: args[:title],
            meta_text: args[:meta_text],
            status: "pending",
            action_label: args[:action_label],
            ai_confirm: cat == "ai_confirm",
            overdue: boolean_param(args[:overdue]) || false,
            due_at: args[:due_at].present? ? Time.zone.parse(args[:due_at].to_s) : nil,
            project: project,
            room: room,
            user: user
          )
          success(item.as_json)
        end
      end

      class AddDecisionsWaitingTool < AddAttentionItemBase; for_category "decisions_waiting"; end
      class AddBlockersTool < AddAttentionItemBase; for_category "blockers"; end
      class AddOutcomesReviewTool < AddAttentionItemBase; for_category "outcomes_review"; end
      class AddMentionsTool < AddAttentionItemBase; for_category "mentions"; end
      class AddMaterialChangesTool < AddAttentionItemBase; for_category "material_changes"; end
      class AddAiConfirmTool < AddAttentionItemBase; for_category "ai_confirm"; end
      class AddKnowledgeProposalsTool < AddAttentionItemBase; for_category "knowledge_proposals"; end

      # Edit action tools
      class EditAttentionItemBase < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def self.category_name
          @category_name
        end
        def self.for_category(cat)
          @category_name = cat
        end

        def name = "edit_#{self.class.category_name}"
        def description = "Update a company-home #{self.class.category_name} attention item"
        def aliases = ["Edit#{self.class.category_name.camelize}"]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer], description: "Attention item ID" },
              title: { type: "string" },
              meta_text: { type: "string" },
              status: { type: "string" },
              action_label: { type: "string" },
              due_at: { type: "string" },
              overdue: { type: "boolean" }
            },
            required: ["item_id"]
          }
        end

        def execute(args)
          item = AttentionItem.find(args[:item_id])
          attrs = {
            title: args[:title],
            meta_text: args[:meta_text],
            status: args[:status],
            action_label: args[:action_label],
            overdue: boolean_param(args[:overdue]),
            due_at: args[:due_at].present? ? Time.zone.parse(args[:due_at].to_s) : nil
          }.compact
          item.update!(attrs)
          success(item.as_json)
        end
      end

      class EditDecisionsWaitingTool < EditAttentionItemBase; for_category "decisions_waiting"; end
      class EditBlockersTool < EditAttentionItemBase; for_category "blockers"; end
      class EditOutcomesReviewTool < EditAttentionItemBase; for_category "outcomes_review"; end
      class EditMentionsTool < EditAttentionItemBase; for_category "mentions"; end
      class EditMaterialChangesTool < EditAttentionItemBase; for_category "material_changes"; end
      class EditAiConfirmTool < EditAttentionItemBase; for_category "ai_confirm"; end
      class EditKnowledgeProposalsTool < EditAttentionItemBase; for_category "knowledge_proposals"; end

      class DeleteAttentionItemTool < Mcp::BaseTool
        def name = "delete_attention_item"
        def description = "Delete an attention item"
        def aliases = ["DeleteAttentionItem"]
        def input_schema
          {
            type: "object",
            properties: { item_id: { type: %w[string integer] } },
            required: ["item_id"]
          }
        end
        def execute(args)
          item = AttentionItem.find(args[:item_id])
          item.destroy!
          success(status: "deleted", id: item.id)
        end
      end
    end
  end
end
