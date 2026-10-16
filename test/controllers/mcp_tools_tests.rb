require "test_helper"

class McpToolsTests < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "MCP Tool User", display_name: "MCP Tool User", email_address: "mcp-tool-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "mcp-tool-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "MCP Tool Project"
      project.slug = "mcp-tool-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "MCP Tool Room", project: @project, creator: @user)
    @task = Task.create!(description: "MCP tool task", project: @project)
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

  test "hello returns the real business result" do
    payload = call_tool("/mcp", "hello")
    assert_equal false, payload.dig("result", "isError")
    assert_equal "Hello, World!", payload.dig("result", "content", 0, "text")
  end

  test "tasks tool reflects real database records" do
    payload = call_tool("/mcp", "tasks", { task_id: @task.id })
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@task.id}"
    assert_includes body, "\"description\": \"#{@task.description}\""
  end
end
