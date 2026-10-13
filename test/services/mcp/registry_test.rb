require "test_helper"

class McpRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class DummyTool < Mcp::BaseTool
    def name = "dummy_tool"
    def description = "A test dummy tool"
    def aliases = ["dummy_alias"]
    def input_schema = { type: "object", properties: { text: { type: "string" } } }
    def execute(args)
      success("Echo: #{args[:text]}")
    end
  end

  setup do
    Mcp::Registry.reset!
    @dummy = DummyTool.new
  end

  test "registers tool and resolves by name and alias" do
    Mcp::Registry.register(@dummy, scopes: %i[action all])

    assert_equal @dummy, Mcp::Registry.find_tool("dummy_tool")
    assert_equal @dummy, Mcp::Registry.find_tool("dummy_alias")
    assert_equal @dummy, Mcp::Registry.find_tool("dummy_tool", scope: :action)
    assert_nil Mcp::Registry.find_tool("dummy_tool", scope: :read)
  end

  test "lists tools for specified scope" do
    Mcp::Registry.register(@dummy, scopes: [:action])
    Mcp::Registry.register(Mcp::Tools::HelloTool.new, scopes: %i[read action])

    action_tools = Mcp::Registry.list_tools(:action)
    assert_equal 2, action_tools.size
    assert_equal %w[dummy_tool hello], action_tools.map { |t| t[:name] }.sort

    read_tools = Mcp::Registry.list_tools(:read)
    assert_equal 1, read_tools.size
    assert_equal ["hello"], read_tools.map { |t| t[:name] }
  end

  test "calls tool and records telemetry in McpCallLog" do
    Mcp::Registry.register(@dummy, scopes: [:all])

    assert_difference -> { McpCallLog.count }, 1 do
      result = Mcp::Registry.call_tool("dummy_tool", { text: "secret_value" }, scope: :all, jsonrpc_id: "req_123")
      assert_equal false, result[:isError]
      assert_equal "Echo: secret_value", result[:content].first[:text]
    end

    log = McpCallLog.recent.first
    assert_equal "req_123", log.jsonrpc_id
    assert_equal "dummy_tool", log.tool_call_name
    assert_equal false, log.is_error
    assert log.duration_ms >= 0
  end

  test "returns error when tool is not found" do
    result = Mcp::Registry.call_tool("missing_tool", {}, scope: :all)
    assert_equal true, result[:isError]
    assert_includes result[:content].first[:text], "Tool 'missing_tool' not found"
  end
end
