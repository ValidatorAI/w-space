require "test_helper"

class McpTaskToolsTests < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "MCP Task User", display_name: "MCP Task User", email_address: "mcp-task-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "mcp-task-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "MCP Task Project"
      project.slug = "mcp-task-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "MCP Task Room", project: @project, creator: @user)
    @task = Task.create!(description: "MCP task cost task", project: @project, room: @room)
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

  test "task-mcp tools/list excludes the hello tool" do
    post "/task-mcp",
         params: {
           jsonrpc: "2.0",
           id: "task_tools_list",
           method: "tools/list",
           params: {}
         }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    tool_names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    refute_includes tool_names, "hello"
  end

  test "tasks endpoint reads the real task data from the database" do
    payload = call_tool("/task-mcp", "tasks", { task_id: @task.id })
    assert_equal false, payload.dig("result", "isError")

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, "\"id\": #{@task.id}"
    assert_includes body, "\"description\": \"#{@task.description}\""
  end

  test "task_cost updates the persisted task values" do
    payload = call_tool("/task-mcp", "task_cost", { task_id: @task.id, token_used: 99, usd_used: 42.5 })
    assert_equal false, payload.dig("result", "isError")

    @task.reload
    assert_equal 99, @task.token_used
    assert_equal 42.5, @task.usd_used

    body = payload.dig("result", "content", 0, "text")
    assert_includes body, '"token_used": 99'
    assert_includes body, '"usd_used": 42.5'
  end
end
