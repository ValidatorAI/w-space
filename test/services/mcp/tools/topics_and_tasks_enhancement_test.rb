require "test_helper"

class TopicsAndTasksEnhancementTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @user = User.create!(name: "edward", display_name: "Edward Nygma", email_address: "edward@example.com", role: :member)
    @project = Project.create!(name: "Project Epsilon", path: "/path/epsilon", slug: "epsilon")
    @room = Rooms::Open.create!(name: "Research Room", creator: @user, project: @project)
    @message = @room.messages.create!(body: "Analyze this document", creator: @user, client_message_id: SecureRandom.uuid)
  end

  test "message analysis tools full lifecycle including get_message_analysis" do
    create_tool = Mcp::Registry.find_tool("create_message_analysis", scope: :action)
    assert create_tool.present?

    res = create_tool.call(
      message_id: @message.id,
      importance_level: 4,
      message_content_summary: "Key architectural decision",
      message_type: "architecture",
      tags: "mcp,arch"
    )
    assert_equal false, res[:isError]
    ma = MessageAnalysis.last
    assert_equal 4, ma.importance_level
    assert_equal "Key architectural decision", ma.message_content_summary

    # get_message_analysis
    get_tool = Mcp::Registry.find_tool("get_message_analysis", scope: :read)
    assert get_tool.present?
    res_get = get_tool.call(message_analysis_id: ma.id)
    assert_equal false, res_get[:isError]
    assert_includes res_get[:content].first[:text], "Key architectural decision"

    # update_message_analysis
    update_tool = Mcp::Registry.find_tool("update_message_analysis", scope: :action)
    res_up = update_tool.call(message_analysis_id: ma.id, importance_level: 5)
    assert_equal false, res_up[:isError]
    assert_equal 5, ma.reload.importance_level

    # delete_message_analysis
    del_tool = Mcp::Registry.find_tool("delete_message_analysis", scope: :action)
    res_del = del_tool.call(message_analysis_id: ma.id)
    assert_equal false, res_del[:isError]
    assert_nil MessageAnalysis.find_by(id: ma.id)
  end

  test "message topic tools including get and update" do
    topic = Topic.create!(name: "Security", project_id: @project.id)
    create_tool = Mcp::Registry.find_tool("create_message_topic", scope: :action)
    res = create_tool.call(message_id: @message.id, topic_id: topic.id)
    assert_equal false, res[:isError]

    mt = MessageTopic.last
    get_tool = Mcp::Registry.find_tool("get_message_topic", scope: :read)
    assert get_tool.present?
    res_get = get_tool.call(message_topic_id: mt.id)
    assert_equal false, res_get[:isError]

    topic2 = Topic.create!(name: "Compliance", project_id: @project.id)
    update_tool = Mcp::Registry.find_tool("update_message_topic", scope: :action)
    assert update_tool.present?
    res_up = update_tool.call(message_topic_id: mt.id, topic_id: topic2.id)
    assert_equal false, res_up[:isError]
    assert_equal topic2.id, mt.reload.topic_id
  end

  test "room history topic tools including get and update" do
    create_tool = Mcp::Registry.find_tool("create_room_history_topic", scope: :action)
    res = create_tool.call(room_id: @room.id, last_state: "Active discussion")
    assert_equal false, res[:isError]

    rht = RoomHistoryTopic.last
    get_tool = Mcp::Registry.find_tool("get_room_history_topic", scope: :read)
    assert get_tool.present?
    res_get = get_tool.call(room_history_topic_id: rht.id)
    assert_equal false, res_get[:isError]
    assert_includes res_get[:content].first[:text], "Active discussion"

    update_tool = Mcp::Registry.find_tool("update_room_history_topic", scope: :action)
    res_up = update_tool.call(room_history_topic_id: rht.id, last_state: "Resolved")
    assert_equal false, res_up[:isError]
    assert_equal "Resolved", rht.reload.last_state
  end

  test "get_task_children collects nested descendants recursively" do
    parent = Task.create!(description: "Parent", project_id: @project.id)
    child = Task.create!(description: "Child", parent_task_id: parent.id, project_id: @project.id)
    grandchild = Task.create!(description: "Grandchild", parent_task_id: child.id, project_id: @project.id)

    tool = Mcp::Registry.find_tool("get_task_children", scope: :task)
    assert tool.present?

    res = tool.call(task_id: parent.id)
    assert_equal false, res[:isError]
    json_text = res[:content].first[:text]

    assert_includes json_text, "Child"
    assert_includes json_text, "Grandchild"

    # Also check alias
    alias_tool = Mcp::Registry.find_tool("get_all_children_tasks", scope: :task)
    assert_equal tool, alias_tool
  end
end
