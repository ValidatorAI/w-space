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
        .order(created_date: :desc, id: :desc)
    end

    @project_tool_logs = @projects.index_with do |project|
      ToolCalLog.includes(:room, :topic)
        .where(project_id: project.id)
        .ordered
    end

    @project_topic_debug = @projects.index_with do |project|
      build_project_topic_debug(project, topics_by_project_id.fetch(project.id, []))
    end
  end

  private
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

    def ensure_admin_debug_enabled
      return if ENV.fetch("ADMIN_DEBUG", ENV.fetch("admin_debug", "false")).to_s.strip.casecmp("true").zero?

      head :not_found
    end
end
