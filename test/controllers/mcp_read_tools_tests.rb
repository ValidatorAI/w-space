require "test_helper"

class McpReadToolsTests < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "MCP Read User", display_name: "MCP Read User", email_address: "mcp-read-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "mcp-read-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "MCP Read Project"
      project.slug = "mcp-read-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "MCP Read Room", project: @project, creator: @user)
    @task = Task.create!(description: "MCP read task", project: @project)
    @approval = ApprovalRequest.create!(room: @room, request_type: "decision", payload: { note: "db read check" })
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

  test "list_rooms returns the same room records persisted in the database" do
    payload = call_tool("/read-mcp", "list_rooms")
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@room.id}"
    assert_includes body, "\"name\": \"#{@room.name}\""
  end

  test "get_task returns the real task stored in the database" do
    payload = call_tool("/task-mcp", "get_task", { task_id: @task.id })
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@task.id}"
    assert_includes body, "\"description\": \"#{@task.description}\""
  end

  test "approval_requests returns the actual stored approval request" do
    payload = call_tool("/mcp", "approval_requests", { request_id: @approval.id })
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@approval.id}"
    assert_includes body, "\"status\": \"#{@approval.status}\""
  end
end
