module Mcp
  module Tools
    module Concerns
      module ResolutionHelpers
        def resolve_project(args)
          project_id = args[:project_id]
          project_name = args[:project_name]

          if project_id.present?
            Project.find_by(id: project_id) || Project.find_by(slug: project_id.to_s)
          elsif project_name.present?
            Mcp::FuzzyMatcher.match_project(project_name)
          end
        end

        def resolve_room(args, project: nil)
          room_id = args[:room_id]
          room_name = args[:room_name]

          if room_id.present?
            Room.find_by(id: room_id)
          elsif room_name.present?
            Mcp::FuzzyMatcher.match_room(room_name, project_id: project&.id)
          end
        end

        def resolve_user(args, project: nil)
          user_id = args[:user_id]
          user_name = args[:user_name]

          if user_id.present?
            User.find_by(id: user_id)
          elsif user_name.present?
            Mcp::FuzzyMatcher.match_user(user_name, project_id: project&.id)
          end
        end

        def resolve_bot(args)
          bot_id = args[:bot_id]
          bot_name = args[:bot_name]

          if bot_id.present?
            User.bot.find_by(id: bot_id)
          elsif bot_name.present?
            Mcp::FuzzyMatcher.match_bot(bot_name)
          end
        end

        def resolve_sender(args, project: nil)
          resolve_bot(args) || resolve_user(args, project: project) || User.first
        end

        def paginate(scope, args)
          page = [args[:page].to_i, 1].max
          per_page = args[:per_page].present? ? args[:per_page].to_i.clamp(1, 100) : 40
          scope.offset((page - 1) * per_page).limit(per_page)
        end
      end
    end
  end
end
