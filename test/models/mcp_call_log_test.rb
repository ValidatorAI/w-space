require "test_helper"

class McpCallLogTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "validates presence of tool_call_name" do
    log = McpCallLog.new
    assert_not log.valid?
    assert_includes log.errors[:tool_call_name], "can't be blank"
  end

  test "creates successfully and scopes by errors and recent" do
    log1 = McpCallLog.create!(
      tool_call_name: "add_message",
      jsonrpc_id: "1",
      is_error: false,
      duration_ms: 12
    )
    log2 = McpCallLog.create!(
      tool_call_name: "add_approval_request",
      jsonrpc_id: "2",
      is_error: true,
      error_message: "Invalid room",
      duration_ms: 25
    )

    assert_includes McpCallLog.errors, log2
    assert_not_includes McpCallLog.errors, log1

    assert_equal [log2, log1], McpCallLog.where(id: [log1.id, log2.id]).recent.to_a
  end
end
