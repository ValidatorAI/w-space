require "test_helper"

class McpKnowledgeToolsTests < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "MCP Knowledge User", display_name: "MCP Knowledge User", email_address: "mcp-knowledge-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "mcp-knowledge-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "MCP Knowledge Project"
      project.slug = "mcp-knowledge-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "MCP Knowledge Room", project: @project, creator: @user)
    @topic = Topic.create!(project: @project, name: "Knowledge DB Topic", active: true, need_an_action: true)
  end

  def call_tool(endpoint, tool_name, arguments = {})
    post endpoint,
         params: {
           jsonrpc: "2.0",
           id: "test_#{tool_name}",
           method: "tools/call",
           params: { name: tool_name, arguments: arguments }
         }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success, "Expected #{endpoint} to dispatch #{tool_name}"
    response.parsed_body
  end

  test "room topic tree tool returns nested topic branches" do
    root = Topic.create!(project: @project, name: "Root topic", active: true, need_an_action: false)
    child = Topic.create!(project: @project, name: "Child topic", parent_topic: root, active: true, need_an_action: false)
    message = @room.messages.create!(body: "Tree test message", creator: @user, client_message_id: SecureRandom.uuid)
    MessageTopic.create!(message: message, topic: root, created_date: Time.current)
    MessageTopic.create!(message: message, topic: child, created_date: Time.current)

    payload = call_tool("/knowledge-mcp", "room_topic_tree", room_id: @room.id)
    body = payload.dig("result", "content", 0, "text")
    assert_equal false, payload.dig("result", "isError")
    assert_includes body, "\"id\": #{root.id}"
    assert_includes body, "\"id\": #{child.id}"

    branch_payload = call_tool("/knowledge-mcp", "room_topic_tree", room_id: @room.id, start_topic_id: root.id, include_root: false)
    branch_body = branch_payload.dig("result", "content", 0, "text")
    assert_equal false, branch_payload.dig("result", "isError")
    assert_includes branch_body, "\"id\": #{child.id}"
    assert_not_includes branch_body, "\"id\": #{root.id}"
  end

  test "search_topics finds matches by name or related topics within project or room" do
    alpha = Topic.create!(project: @project, name: "Alpha strategy", related_topics: "beta,launch", active: true, need_an_action: false)
    beta = Topic.create!(project: @project, name: "Beta launch", active: true, need_an_action: false)
    gamma = Topic.create!(project: @project, name: "Gamma roadmap", active: true, need_an_action: false)

    message = @room.messages.create!(body: "Search test message", creator: @user, client_message_id: SecureRandom.uuid)
    MessageTopic.create!(message: message, topic: alpha, created_date: Time.current)
    MessageTopic.create!(message: message, topic: beta, created_date: Time.current)

    payload = call_tool("/knowledge-mcp", "search_topics", project_id: @project.id, query: "beta")
    body = payload.dig("result", "content", 0, "text")
    assert_equal false, payload.dig("result", "isError")
    assert_includes body, "\"id\": #{beta.id}"
    assert_includes body, "\"id\": #{alpha.id}"
    assert_not_includes body, "\"id\": #{gamma.id}"

    room_payload = call_tool("/knowledge-mcp", "search_topics", room_id: @room.id, query: "alpha")
    room_body = room_payload.dig("result", "content", 0, "text")
    assert_equal false, room_payload.dig("result", "isError")
    assert_includes room_body, "\"id\": #{alpha.id}"
  end

  test "topics tool reflects real project topics from the database" do
    payload = call_tool("/knowledge-mcp", "topics")
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@topic.id}"
    assert_includes body, "\"name\": \"#{@topic.name}\""
  end
end
