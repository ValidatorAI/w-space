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

  test "topics tool reflects real project topics from the database" do
    payload = call_tool("/knowledge-mcp", "topics")
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@topic.id}"
    assert_includes body, "\"name\": \"#{@topic.name}\""
  end
end
