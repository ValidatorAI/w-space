require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
  end

  test "initialize method returns capabilities and protocolVersion" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: 1, method: "initialize", params: {} }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body

    assert_equal "2.0", data["jsonrpc"]
    assert_equal 1, data["id"]
    assert_equal "2024-11-05", data.dig("result", "protocolVersion")
    assert_equal "bonfire-mcp", data.dig("result", "serverInfo", "name")
  end

  test "ping method returns empty result" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: "ping_1", method: "ping", params: {} }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body

    assert_equal "2.0", data["jsonrpc"]
    assert_equal "ping_1", data["id"]
    assert_equal({}, data["result"])
  end

  test "notifications/initialized returns no_content when no id is provided" do
    post "/mcp",
         params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :no_content
  end

  test "tools/list returns registered tools" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body
    tools = data.dig("result", "tools")

    assert tools.is_a?(Array)
    tool_names = tools.map { |t| t["name"] }
    assert_includes tool_names, "hello"
  end

  test "tools/call executes tool successfully and logs to McpCallLog" do
    assert_difference -> { McpCallLog.count }, 1 do
      post "/mcp",
           params: {
             jsonrpc: "2.0",
             id: 3,
             method: "tools/call",
             params: { name: "hello", arguments: { name: "Bonfire" } }
           }.to_json,
           headers: { "Content-Type" => "application/json" }

      assert_response :success
    end

    data = response.parsed_body
    assert_equal false, data.dig("result", "isError")
    content = data.dig("result", "content").first["text"]
    assert_equal "Hello, Bonfire!", content

    log = McpCallLog.recent.first
    assert_equal "hello", log.tool_call_name
    assert_equal false, log.is_error
  end

  test "tools/call returns error when tool is not found" do
    post "/action-mcp",
         params: {
           jsonrpc: "2.0",
           id: 4,
           method: "tools/call",
           params: { name: "non_existent_tool", arguments: {} }
         }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body
    assert_equal true, data.dig("result", "isError")
    assert_includes data.dig("result", "content").first["text"], "Tool 'non_existent_tool' not found"
  end

  test "returns -32700 for malformed json" do
    post "/mcp",
         params: "invalid json string {",
         headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    data = response.parsed_body
    assert_equal(-32700, data.dig("error", "code"))
    assert_includes data.dig("error", "message"), "Parse error"
  end

  test "returns -32600 for missing method" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: 5 }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body
    assert_equal(-32600, data.dig("error", "code"))
  end

  test "returns -32601 for unknown method" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: 6, method: "unknown/method" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body
    assert_equal(-32601, data.dig("error", "code"))
  end

  test "returns -32602 for invalid tools/call parameters" do
    post "/mcp",
         params: { jsonrpc: "2.0", id: 7, method: "tools/call", params: {} }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
    data = response.parsed_body
    assert_equal(-32602, data.dig("error", "code"))
  end

  test "scoped endpoints respond properly" do
    %w[/action-mcp /read-mcp /knowledge-mcp /task-mcp].each do |endpoint|
      post endpoint,
           params: { jsonrpc: "2.0", id: "scope_test", method: "tools/list", params: {} }.to_json,
           headers: { "Content-Type" => "application/json" }

      assert_response :success
      data = response.parsed_body
      assert data.dig("result", "tools").is_a?(Array)
    end
  end
end
