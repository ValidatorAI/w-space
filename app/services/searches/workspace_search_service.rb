module Searches
  class WorkspaceSearchService
    DEFAULT_LIMIT = 8

    def initialize(user:, query:, page: 1, per_page: DEFAULT_LIMIT)
      @user = user
      @query = query.to_s.strip
      @page = [page.to_i, 1].max
      @per_page = [per_page.to_i, 1].max
    end

    def total_count
      return 0 if @query.blank?

      build_results.count
    end

    def call
      return [] if @query.blank?

      results = build_results
      page_results = results.drop((@page - 1) * @per_page).first(@per_page)
      page_results
    end

    private
      def build_results
        (message_results + room_results + project_results + project_entity_results)
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
            url: room_search_url(room)
          }
        end
      end

      def project_results
        @user.projects.includes(:project_users).filter_map do |project|
          score = score_for(project.name, project.description.to_s, project.path.to_s)
          next if score.zero?

          {
            type: "project",
            title: project.name,
            snippet: project.description.presence || project.path,
            project_name: project.name,
            created_at: project.created_at,
            score: score,
            url: project_search_url(project)
          }
        end
      end

      def project_entity_results
        return [] if @user.projects.none?

        @user.projects.includes(
          :adrs,
          :knowledge_items,
          :todos,
          :milestones,
          :notes,
          :bottlenecks,
          :project_all_hands_decisions,
          :project_all_hands_action_items,
          :project_all_hands_takeaways,
          :tasks,
          :topics,
          :directory_items,
          :external_assets,
          :knowledge_activities,
          :attention_items
        ).flat_map do |project|
          [
            entity_results(project, project.adrs.active, "adr", :title, :identifier, :status),
            entity_results(project, project.knowledge_items.active, "knowledge", :title, :description, :badge),
            entity_results(project, project.todos, "todo", :title, :meta_text),
            entity_results(project, project.milestones.active, "milestone", :title, :description),
            entity_results(project, project.notes.active, "note", :title, :content, :tags),
            entity_results(project, project.bottlenecks, "bottleneck", :title, :description, :severity),
            entity_results(project, project.project_all_hands_decisions.active, "all_hands_decision", :title, :impact, :basis),
            entity_results(project, project.project_all_hands_action_items.active, "all_hands_action_item", :title, :assignee_name),
            entity_results(project, project.project_all_hands_takeaways.active, "all_hands_takeaway", :category, :content),
            entity_results(project, project.tasks, "task", :description, :status, :priority),
            entity_results(project, project.topics, "topic", :name, :description),
            entity_results(project, project.directory_items.active, "directory_item", :name, :file_path, :content),
            entity_results(project, project.external_assets.active, "external_asset", :title, :meta_text, :url),
            entity_results(project, project.knowledge_activities.active, "knowledge_activity", :action_text, :target_path, :target_url),
            entity_results(project, project.attention_items.recent, "attention_item", :title, :category, :action_label),
          ].flatten
        end + attention_item_results
      end

      def attention_item_results
        AttentionItem.for_user(@user).recent.filter_map do |record|
          title = record.title.to_s.strip.presence || "Attention item"
          searchable_text = [
            record.category,
            record.action_label,
            record.title,
            record.respond_to?(:description) ? record.description : nil,
            record.respond_to?(:body) ? record.body : nil
          ].filter_map { |value| value.to_s.strip.presence }.join(" ")
          score = score_for(title, searchable_text, record.project&.name.to_s)
          next if score.zero?

          {
            type: "attention_item",
            title: title,
            snippet: searchable_text.presence || title,
            project_name: record.project&.name || "General",
            created_at: record.created_at,
            score: score,
            url: project_search_url(record.project, "attention_item")
          }
        end
      end

      def entity_results(project, records, type, *fields)
        records.filter_map do |record|
          title = if record.respond_to?(:title)
            record.title.to_s.strip.presence
          elsif record.respond_to?(:name)
            record.name.to_s.strip.presence
          elsif record.respond_to?(:description)
            record.description.to_s.strip.presence
          else
            record.class.name.demodulize.titleize
          end
          next if title.blank?

          searchable_text = fields.filter_map do |field|
            value = record.public_send(field) if record.respond_to?(field)
            value.to_s.strip.presence
          end.join(" ")

          score = score_for(title, searchable_text, project.name)
          next if score.zero?

          {
            type: type,
            title: title,
            snippet: searchable_text.presence || title,
            project_name: project.name,
            created_at: record.try(:created_at) || project.created_at,
            score: score,
            url: project_search_url(project, type)
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
            url: room_search_url(room)
          }
        end
      end

      def room_search_url(room)
        routes = Rails.application.routes.url_helpers
        routes.respond_to?(:room_path) ? routes.room_path(room) : "#"
      end

      def project_search_url(project, type = nil)
        return "#" if project.blank?

        routes = Rails.application.routes.url_helpers
        type_name = type.to_s

        route_map = {
          "project" => :user_company_project_overview_path,
          "todo" => :user_company_project_status_path,
          "task" => :user_company_project_status_path,
          "milestone" => :user_company_project_status_path,
          "all_hands_decision" => :user_company_project_all_hands_path,
          "all_hands_action_item" => :user_company_project_all_hands_path,
          "all_hands_takeaway" => :user_company_project_all_hands_path,
          "knowledge" => :user_company_project_knowledge_path,
          "knowledge_activity" => :user_company_project_knowledge_path,
          "note" => :user_company_project_knowledge_path,
          "directory_item" => :user_company_project_knowledge_path,
          "external_asset" => :user_company_project_knowledge_path,
          "adr" => :user_company_project_knowledge_path,
          "attention_item" => :user_company_project_status_path,
          "room" => nil,
          "message" => nil
        }

        helper = route_map[type_name] || :user_company_project_overview_path
        if routes.respond_to?(helper)
          routes.public_send(helper, user_id: "me", id: project.id)
        else
          routes.respond_to?(:user_company_project_overview_path) ? routes.user_company_project_overview_path(user_id: "me", id: project.id) : "#"
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
