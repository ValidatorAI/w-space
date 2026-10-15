module Mcp
  module Tools
    module RoomContext
      class RoomDecisionContextTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "room_decision_context"
        def description = "Read room decision links and project ADR metadata"
        def aliases = ["RoomDecisionContext", "room_decisions"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          return failure("Room not found") unless room

          decisions = room.decision_rooms.includes(:project_adr).map do |decision_room|
            adr = decision_room.project_adr
            next if adr.nil?

            {
              id: decision_room.id,
              room_decision_id: decision_room.id,
              adr_id: adr.id,
              identifier: adr.identifier,
              title: adr.title,
              status: adr.status,
              decision_date: adr.decision_date&.iso8601,
              created_at: adr.created_at&.iso8601
            }
          end.compact

          success(
            room_id: room.id,
            room_name: room.name,
            project_id: room.project_id,
            decisions: decisions
          )
        end
      end

      class RoomEvidenceTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "room_evidence"
        def description = "Read room evidence and source provenance metadata"
        def aliases = ["RoomEvidence", "room_sources"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          return failure("Room not found") unless room

          evidence = room.room_evidences.includes(:project_external_asset, :project_knowledge_item).ordered.map do |link|
            item = link.entity
            {
              id: link.id,
              entity_type: link.project_external_asset ? "external_asset" : "knowledge_item",
              entity_id: item&.id,
              entity_title: link.entity_title,
              summary: link.display_summary,
              source_label: link.source_label.presence || link.entity_title,
              author_name: link.author_name,
              visibility: link.visibility,
              visibility_label: link.visibility_label,
              freshness_label: link.freshness_label,
              provenance_summary: link.provenance_summary,
              source_updated_at: link.source_updated_at&.iso8601,
              active: link.active
            }
          end

          success(
            room_id: room.id,
            room_name: room.name,
            project_id: room.project_id,
            evidence: evidence
          )
        end
      end

      class RoomEconomicsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "room_economics"
        def description = "Read room decision effort, learning value, and risk framing"
        def aliases = ["RoomEconomics", "room_risk"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          return failure("Room not found") unless room

          economics = room.decision_room_economics.order(:created_at).last
          if economics.nil?
            return success(
              room_id: room.id,
              room_name: room.name,
              project_id: room.project_id,
              risk_level: nil,
              risk_label: nil,
              research_effort: nil,
              guided_build_effort: nil,
              expected_learning_value: nil
            )
          end

          success(
            room_id: room.id,
            room_name: room.name,
            project_id: room.project_id,
            decision_room_id: economics.decision_room_id,
            risk_level: economics.risk_level,
            risk_label: economics.risk_label,
            research_effort: economics.research_effort,
            guided_build_effort: economics.guided_build_effort,
            expected_learning_value: economics.expected_learning_value
          )
        end
      end

      class RoomContextSummaryTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "room_context_summary"
        def description = "Summarize the current room decision, evidence, and risk context"
        def aliases = ["RoomContextSummary"]

        def input_schema
          {
            type: "object",
            properties: {
              room_id: { type: %w[string integer] },
              room_name: { type: "string" },
              project_id: { type: %w[string integer] },
              project_name: { type: "string" }
            }
          }
        end

        def execute(args)
          project = resolve_project(args)
          room = resolve_room(args, project: project)
          return failure("Room not found") unless room

          decisions = room.decision_rooms.includes(:project_adr).map do |decision_room|
            adr = decision_room.project_adr
            next if adr.nil?

            {
              id: adr.id,
              identifier: adr.identifier,
              title: adr.title,
              status: adr.status
            }
          end.compact

          evidence = room.room_evidences.includes(:project_external_asset, :project_knowledge_item).ordered.map do |link|
            {
              id: link.id,
              title: link.entity_title,
              summary: link.display_summary,
              freshness_label: link.freshness_label
            }
          end

          economics = room.decision_room_economics.order(:created_at).last

          success(
            room_id: room.id,
            room_name: room.name,
            project_id: room.project_id,
            outcome: room.project&.description.presence || evidence.first&.dig(:summary),
            decisions: decisions,
            evidence: evidence,
            risk_level: economics&.risk_level,
            risk_label: economics&.risk_label,
            research_effort: economics&.research_effort,
            guided_build_effort: economics&.guided_build_effort,
            expected_learning_value: economics&.expected_learning_value
          )
        end
      end
    end
  end
end
