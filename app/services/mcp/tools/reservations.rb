module Mcp
  module Tools
    module Reservations
      class CheckFileConflictsTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "check_file_conflicts"
        def description = "Check whether a set of file patterns conflicts with active reservations"
        def aliases = ["CheckFileConflicts"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              patterns: { type: "array", items: { type: "string" } }
            },
            required: ["patterns"]
          }
        end

        def execute(args)
          project = resolve_project(args)
          return failure("Project not found") unless project

          patterns = Array(args[:patterns]).flatten.filter_map { |p| p.to_s.strip.presence }
          conflicts = FileReservationService.conflicts?(project: project, patterns: patterns)

          success({ conflicts: conflicts.map { |reservation| conflict_payload(reservation) } })
        end

        private

        def conflict_payload(reservation)
          {
            id: reservation.id,
            patterns: Array(reservation.patterns),
            holder_name: reservation.holder&.name || "unknown",
            expires_at: reservation.expires_at.iso8601,
            time_remaining_seconds: reservation.time_remaining.to_i
          }
        end
      end

      class ReserveFileTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "reserve_file"
        def description = "Reserve a file or glob pattern for an agent or user"
        def aliases = ["ReserveFile"]

        def input_schema
          {
            type: "object",
            properties: {
              project_id: { type: %w[string integer] },
              project_name: { type: "string" },
              project: { type: %w[string integer] },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              patterns: { type: "array", items: { type: "string" } },
              exclusive: { type: "boolean" },
              reason: { type: "string" },
              ttl_seconds: { type: "integer" }
            },
            required: ["patterns"]
          }
        end

        def execute(args)
          project = resolve_project(args) || (args[:project].present? ? Project.find_by(id: args[:project]) : nil)
          return failure("Project not found") unless project

          user = resolve_user(args, project: project)
          return failure("User not found") unless user

          patterns = Array(args[:patterns]).flatten.filter_map { |p| p.to_s.strip.presence }
          return failure("Patterns are required") if patterns.empty?

          begin
            reservation = FileReservationService.reserve(
              project: project,
              patterns: patterns,
              holder: user,
              exclusive: args.key?(:exclusive) ? boolean_param(args[:exclusive]) : true,
              reason: args[:reason].presence,
              ttl_seconds: args[:ttl_seconds].presence
            )
            success(reservation_payload(reservation))
          rescue FileReservationService::ConflictError => e
            failure("conflict: #{e.conflicts.map { |conflict| "#{conflict[:holder_name]} on #{conflict[:patterns].join(', ')}" }.join('; ')}")
          end
        end

        private

        def reservation_payload(reservation)
          {
            id: reservation.id,
            project_id: reservation.project_id,
            patterns: Array(reservation.patterns),
            exclusive: reservation.exclusive,
            reason: reservation.reason,
            holder: reservation.holder ? { id: reservation.holder.id, name: reservation.holder.name } : nil,
            expires_at: reservation.expires_at.iso8601,
            time_remaining_seconds: reservation.time_remaining.to_i
          }
        end
      end

      class RenewFileReservationTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "renew_file_reservation"
        def description = "Renew an active file reservation if the current holder is allowed to do so"
        def aliases = ["RenewFileReservation"]

        def input_schema
          {
            type: "object",
            properties: {
              reservation_id: { type: %w[string integer] },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" },
              ttl_seconds: { type: "integer" }
            },
            required: ["reservation_id"]
          }
        end

        def execute(args)
          reservation = FileReservation.find_by(id: args[:reservation_id])
          return failure("Reservation not found") unless reservation

          user = resolve_user(args)
          return failure("User not found") unless user

          begin
            updated = FileReservationService.renew(
              reservation: reservation,
              holder: user,
              ttl_seconds: args[:ttl_seconds].presence || 3600
            )
            success(reservation_payload(updated))
          rescue FileReservationService::ForbiddenError
            failure("not holder")
          rescue FileReservationService::ExpiredError
            failure("expired")
          end
        end

        private

        def reservation_payload(reservation)
          {
            id: reservation.id,
            project_id: reservation.project_id,
            patterns: Array(reservation.patterns),
            exclusive: reservation.exclusive,
            reason: reservation.reason,
            holder: reservation.holder ? { id: reservation.holder.id, name: reservation.holder.name } : nil,
            expires_at: reservation.expires_at.iso8601,
            time_remaining_seconds: reservation.time_remaining.to_i
          }
        end
      end

      class ReleaseFileReservationTool < Mcp::BaseTool
        include Mcp::Tools::Concerns::ResolutionHelpers

        def name = "release_file_reservation"
        def description = "Release an active reservation after work is complete"
        def aliases = ["ReleaseFileReservation"]

        def input_schema
          {
            type: "object",
            properties: {
              reservation_id: { type: %w[string integer] },
              user_id: { type: %w[string integer] },
              user_name: { type: "string" }
            },
            required: ["reservation_id"]
          }
        end

        def execute(args)
          reservation = FileReservation.find_by(id: args[:reservation_id])
          user = resolve_user(args)

          if reservation.present? && user.present?
            begin
              FileReservationService.release(reservation: reservation, holder: user)
            rescue FileReservationService::ForbiddenError
              return failure("not holder")
            end
          elsif reservation.present?
            reservation.destroy
          end

          success(status: "released", reservation_id: args[:reservation_id])
        end
      end
    end
  end
end
