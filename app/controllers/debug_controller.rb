class DebugController < ApplicationController
  before_action :ensure_admin_debug_enabled
  before_action :ensure_can_administer

  def show
    @projects = Project.order(:name).to_a
    topics_by_project_id = Topic.where(project_id: @projects.map(&:id)).order(:created_at, :id).group_by(&:project_id)

    all_parent_ids = topics_by_project_id.values.flatten.filter_map(&:parent_topic_id).uniq
    @parent_topic_project_lookup = Topic.where(id: all_parent_ids).pluck(:id, :project_id).to_h

    @project_room_history = @projects.index_with do |project|
      RoomHistoryTopic.includes(:room, :topic)
        .joins(:room)
        .where(rooms: { project_id: project.id })
        .order(created_date: :asc, id: :asc)
        .group_by { |entry| entry.room }
    end

    @project_tool_logs = @projects.index_with do |project|
      build_project_tool_log_groups(project)
    end

    @project_topic_debug = @projects.index_with do |project|
      build_project_topic_debug(project, topics_by_project_id.fetch(project.id, []))
    end
  end

  def topic
    @topic = Topic.includes(:project, :parent_topic, :child_topics)
      .find(params[:id])

    @topic_room_history = RoomHistoryTopic.includes(:room, :topic)
      .where(topic_id: @topic.id)
      .order(created_date: :asc, id: :asc)
      .to_a

    @topic_tool_logs = ToolCalLog.includes(:room, :topic)
      .where(topic_id: @topic.id)
      .ordered
      .to_a

    @topic_messages = MessageTopic.includes(:message)
      .where(topic_id: @topic.id)
      .order(created_date: :asc, id: :asc)
      .to_a

    @topic_child_topics = @topic.child_topics.order(:created_at, :id).to_a
  end

  def message
    @message = Message.includes(:room, :creator, :message_topics)
      .find(params[:id])

    @related_topics = @message.message_topics
      .includes(:topic)
      .order(created_date: :asc, id: :asc)
      .map(&:topic)
      .compact
  end

  def output_events
    @filters = {
      flag: params[:flag].to_s.presence,
      project_id: params[:project_id].to_s.presence,
      synced: params[:synced].to_s.presence,
      status: params[:status].to_s.presence
    }

    @event_type_options = OutputEvent.order(:event_type).distinct.pluck(:event_type)
    @project_id_options = OutputEvent.pluck(:event_data).filter_map do |event_data|
      next if event_data.blank?

      payload = event_data.to_h.stringify_keys
      project_id = payload["project_id"]
      next if project_id.blank?

      project_id.to_s
    end.uniq.sort_by { |value| value.to_i }
    @status_options = OutputEvent.pluck(:event_data).filter_map do |event_data|
      status_value(event_data)
    end.uniq.sort

    scope = OutputEvent.order(created_at: :desc, id: :desc)

    if @filters[:flag].present?
      scope = scope.where(event_type: @filters[:flag])
    end

    @output_events = scope.to_a

    if @filters[:project_id].present?
      project_id = @filters[:project_id].to_i
      @output_events.select! do |event|
        event.event_data.to_h.stringify_keys["project_id"].to_s == project_id.to_s
      end
    end

    if @filters[:synced].present?
      synced_value = ActiveModel::Type::Boolean.new.cast(@filters[:synced])
      @output_events.select! { |event| event.synced == synced_value }
    end

    if @filters[:status].present?
      @output_events.select! do |event|
        status_value(event.event_data).to_s == @filters[:status].to_s
      end
    end

    @output_events = @output_events.first(200)
  end

  def hermes_status
    @hermes_status = Hermes::Client.new.api_status
    @status_rows = normalize_status_rows(@hermes_status)
    @active_workers = extract_status_numeric_value(@hermes_status, "active_workers", "active_agents", "workers", "active_sessions")
  end

  private
    def build_project_tool_log_groups(project)
      logs = ToolCalLog.includes(:room, :topic)
        .where(project_id: project.id)
        .ordered
        .to_a

      {
        project_logs: logs.select { |log| log.room_id.blank? },
        room_logs: logs.select { |log| log.room_id.present? && log.topic_id.blank? }
          .group_by { |log| log.room },
        topic_logs: logs.select { |log| log.topic_id.present? }
          .group_by { |log| log.topic }
      }
    end

    def build_project_topic_debug(project, topics)
      topics_by_id = topics.index_by(&:id)
      children_by_parent_id = topics.group_by(&:parent_topic_id)

      children_by_parent_id.each_value do |siblings|
        siblings.sort_by! { |topic| [topic.created_at || Time.at(0), topic.id] }
      end

      root_topics = children_by_parent_id.fetch(nil, [])

      reasons_by_topic_id = Hash.new { |hash, key| hash[key] = [] }

      topics.each do |topic|
        parent_id = topic.parent_topic_id
        next if parent_id.blank?
        next if topics_by_id.key?(parent_id)

        external_parent_project_id = @parent_topic_project_lookup[parent_id]
        if external_parent_project_id.nil?
          reasons_by_topic_id[topic.id] << "missing parent id=#{parent_id}"
        else
          reasons_by_topic_id[topic.id] << "parent belongs to project id=#{external_parent_project_id}"
        end
      end

      visited = {}
      root_topics.each do |topic|
        walk_topic_tree(topic, children_by_parent_id, visited, {})
      end

      topics.each do |topic|
        next if visited[topic.id]

        reasons_by_topic_id[topic.id] << "not reachable from a root topic"
      end

      anomaly_entries = topics.filter_map do |topic|
        reasons = reasons_by_topic_id[topic.id]
        next if reasons.blank?

        { topic: topic, reasons: reasons.uniq }
      end

      {
        project: project,
        roots: root_topics,
        children_by_parent_id: children_by_parent_id,
        anomaly_entries: anomaly_entries
      }
    end

    def walk_topic_tree(topic, children_by_parent_id, visited, path)
      return if visited[topic.id]

      visited[topic.id] = true
      path[topic.id] = true

      children_by_parent_id.fetch(topic.id, []).each do |child|
        next if path[child.id]

        walk_topic_tree(child, children_by_parent_id, visited, path)
      end

      path.delete(topic.id)
    end

    def status_value(event_data)
      value = event_data
      return if value.blank?

      if value.is_a?(Hash)
        return value["status"] if value.key?("status")

        value.each_value do |nested_value|
          result = status_value(nested_value)
          return result if result.present?
        end
      elsif value.is_a?(Array)
        value.each do |item|
          result = status_value(item)
          return result if result.present?
        end
      end

      nil
    end

    def normalize_status_rows(status_payload)
      data = status_payload.to_h if status_payload.respond_to?(:to_h)
      return [] unless data.is_a?(Hash)

      data.map { |key, value| [key.to_s, value] }
    end

    def extract_status_numeric_value(status_payload, *keys)
      data = status_payload.to_h if status_payload.respond_to?(:to_h)
      return nil unless data.is_a?(Hash)

      keys.each do |key|
        value = data[key]
        return value if value.present?
      end

      nil
    end

    def ensure_admin_debug_enabled
      return if ENV.fetch("ADMIN_DEBUG", ENV.fetch("admin_debug", "false")).to_s.strip.casecmp("true").zero?

      head :not_found
    end
end
