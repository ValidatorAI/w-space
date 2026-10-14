module Searches
  class WorkspaceSearchService
    DEFAULT_LIMIT = 5

    def initialize(user:, query:, page: 1, per_page: DEFAULT_LIMIT)
      @user = user
      @query = query.to_s.strip
      @page = [page.to_i, 1].max
      @per_page = [per_page.to_i, 1].max
    end

    def call
      return [] if @query.blank?

      results = build_results
      page_results = results.drop((@page - 1) * @per_page).first(@per_page)
      page_results
    end

    private
      def build_results
        message_results + room_results
          .sort_by { |result| [result[:score], result[:created_at]] }
          .reverse
      end

      def room_results
        @user.rooms.includes(:project).active.order(created_at: :desc).filter_map do |room|
          score = score_for(room.name, room.project&.name.to_s)
          next if score.zero?

          {
            type: "room",
            title: room.name,
            snippet: room.name,
            project_name: room.project&.name || "General",
            created_at: room.created_at,
            score: score,
            url: Rails.application.routes.url_helpers.room_path(room)
          }
        end
      end

      def message_results
        @user.reachable_messages.includes(:room).order(created_at: :desc).filter_map do |message|
          room = message.room
          score = score_for(message.plain_text_body, room&.name.to_s, room&.project&.name.to_s)
          next if score.zero?

          {
            type: "message",
            title: message.plain_text_body.to_s.strip.presence || "Message",
            snippet: message.plain_text_body.to_s.strip,
            project_name: room&.project&.name || "General",
            created_at: message.created_at,
            score: score,
            url: Rails.application.routes.url_helpers.room_path(room)
          }
        end
      end

      def score_for(*fields)
        return 0 if @query.blank?

        normalized_query = normalize(@query)
        return 0 if normalized_query.blank?

        query_tokens = normalized_query.split(/\s+/)
        score = 0

        fields.each do |field|
          next if field.blank?

          value = normalize(field)
          next if value.blank?

          if value == normalized_query
            score += 100
          end

          query_tokens.each do |token|
            score += 20 if value.include?(token)
            score += 10 if value.start_with?(token)
            score += 8 if value.split.any? { |part| part.start_with?(token) }
          end
        end

        score
      end

      def normalize(value)
        value.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
      end
  end
end
