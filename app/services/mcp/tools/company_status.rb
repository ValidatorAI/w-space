module Mcp
  module Tools
    module CompanyStatus
      class CompanyStatusPeriodTool < Mcp::BaseTool
        def name = "company_status_period"
        def description = "List, get, create, update, or delete company status periods"
        def aliases = ["CompanyStatusPeriod"]

        def input_schema
          {
            type: "object",
            properties: {
              period_id: { type: %w[string integer], description: "Period ID for get/edit/delete" },
              slug: { type: "string" },
              name: { type: "string" },
              starts_on: { type: "string" },
              ends_on: { type: "string" },
              current: { type: "boolean" },
              delete: { type: "boolean" }
            }
          }
        end

        def execute(args)
          if args[:period_id].present?
            period = CompanyStatusPeriod.find(args[:period_id])
            if boolean_param(args[:delete])
              period.destroy!
              return success(status: "deleted", id: period.id)
            end

            if args[:name].present? || args[:slug].present? || args.key?(:current)
              period.update!(
                name: args[:name] || period.name,
                slug: args[:slug] || period.slug,
                starts_on: args[:starts_on].presence || period.starts_on,
                ends_on: args[:ends_on].presence || period.ends_on,
                current: args.key?(:current) ? boolean_param(args[:current]) : period.current
              )
            end
            return success(period.as_json.merge(status_payload: period.as_status_payload))
          end

          if args[:name].present?
            slug = args[:slug].presence || args[:name].parameterize
            period = CompanyStatusPeriod.create!(
              name: args[:name],
              slug: slug,
              starts_on: args[:starts_on],
              ends_on: args[:ends_on],
              current: boolean_param(args[:current]) || false
            )
            return success(period.as_json)
          end

          periods = CompanyStatusPeriod.ordered.to_a
          success(periods.map(&:as_json))
        end
      end

      class AddCompanyStatusPeriodTool < Mcp::BaseTool
        def name = "add_company_status_period"
        def description = "Create a company status period"
        def aliases = ["AddCompanyStatusPeriod"]

        def input_schema
          {
            type: "object",
            properties: {
              name: { type: "string" },
              slug: { type: "string" },
              starts_on: { type: "string" },
              ends_on: { type: "string" },
              current: { type: "boolean" }
            },
            required: ["name"]
          }
        end

        def execute(args)
          slug = args[:slug].presence || args[:name].parameterize
          period = CompanyStatusPeriod.create!(
            name: args[:name],
            slug: slug,
            starts_on: args[:starts_on],
            ends_on: args[:ends_on],
            current: boolean_param(args[:current]) || false
          )
          success(period.as_json)
        end
      end

      class EditCompanyStatusPeriodTool < Mcp::BaseTool
        def name = "edit_company_status_period"
        def description = "Update a company status period"
        def aliases = ["EditCompanyStatusPeriod"]

        def input_schema
          {
            type: "object",
            properties: {
              period_id: { type: %w[string integer] },
              name: { type: "string" },
              slug: { type: "string" },
              starts_on: { type: "string" },
              ends_on: { type: "string" },
              current: { type: "boolean" }
            },
            required: ["period_id"]
          }
        end

        def execute(args)
          period = CompanyStatusPeriod.find(args[:period_id])
          attrs = {
            name: args[:name],
            slug: args[:slug],
            starts_on: args[:starts_on],
            ends_on: args[:ends_on],
            current: args.key?(:current) ? boolean_param(args[:current]) : nil
          }.compact
          period.update!(attrs)
          success(period.as_json)
        end
      end

      # Stream category base tool (priorities, progress, risks, dependencies, changes, decisions, learnings)
      class StatusItemCategoryBaseTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def self.category_name
          @category_name
        end
        def self.for_category(cat)
          @category_name = cat
        end

        def name = self.class.category_name
        def description = "List or manage company status #{name} items"
        def aliases = [name.camelize]

        def input_schema
          {
            type: "object",
            properties: {
              item_id: { type: %w[string integer], description: "Item ID for get/edit/delete" },
              company_status_period_id: { type: %w[string integer] },
              title: { type: "string" },
              summary: { type: "string" },
              details: { type: "string" },
              status: { type: "string" },
              health: { type: "string" },
              badge: { type: "string" },
              owner_name: { type: "string" },
              percent: { type: %w[string integer] },
              evidence: { type: "string" },
              impact: { type: "string" },
              delete: { type: "boolean" },
              page: { type: "integer" },
              per_page: { type: "integer" }
            }
          }
        end

        def execute(args)
          cat = self.class.category_name

          if args[:item_id].present?
            item = CompanyStatusItem.find(args[:item_id])
            if boolean_param(args[:delete])
              item.destroy!
              return success(status: "deleted", id: item.id)
            end

            if args[:title].present? || args[:summary].present? || args[:details].present? || args[:status].present? || args[:health].present?
              attrs = {
                title: args[:title],
                subtitle: args[:summary],
                text: args[:details],
                status_label: args[:status],
                color: args[:badge] || args[:health],
                owner: args[:owner_name],
                percent: args[:percent],
                evidence: args[:evidence],
                impact: args[:impact]
              }.compact
              item.update!(attrs)
            end
            return success(item.as_status_payload)
          end

          # Create item if title provided
          if args[:title].present?
            period = if args[:company_status_period_id].present?
                       CompanyStatusPeriod.find(args[:company_status_period_id])
                     else
                       CompanyStatusPeriod.current.first || CompanyStatusPeriod.ordered.first || CompanyStatusPeriod.create!(name: "Current Period", slug: "current", current: true)
                     end

            item = period.company_status_items.create!(
              category: cat,
              title: args[:title],
              subtitle: args[:summary],
              text: args[:details],
              status_label: args[:status].presence || "active",
              color: args[:badge] || args[:health],
              owner: args[:owner_name],
              percent: args[:percent],
              evidence: args[:evidence],
              impact: args[:impact]
            )
            return success(item.as_status_payload)
          end

          # List items
          scope = CompanyStatusItem.for_category(cat)
          if args[:company_status_period_id].present?
            scope = scope.where(company_status_period_id: args[:company_status_period_id])
          end

          items = paginate(scope.ordered, args)
          success(items.map(&:as_status_payload))
        end
      end

      class PrioritiesTool < StatusItemCategoryBaseTool; for_category "priorities"; end
      class ProgressTool < StatusItemCategoryBaseTool; for_category "progress"; end
      class RisksTool < StatusItemCategoryBaseTool; for_category "risks"; end
      class DependenciesTool < StatusItemCategoryBaseTool; for_category "dependencies"; end
      class ChangesTool < StatusItemCategoryBaseTool; for_category "changes"; end
      class DecisionsTool < StatusItemCategoryBaseTool; for_category "decisions"; end
      class LearningsTool < StatusItemCategoryBaseTool; for_category "learnings"; end
    end
  end
end
