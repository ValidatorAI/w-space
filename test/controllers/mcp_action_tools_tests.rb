require "test_helper"

class McpActionToolsTests < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "MCP Action User", display_name: "MCP Action User", email_address: "mcp-action-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "mcp-action-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "MCP Action Project"
      project.slug = "mcp-action-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "MCP Action Room", project: @project, creator: @user)
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

  test "add_approval_request creates a persisted approval record" do
    assert_difference -> { ApprovalRequest.count }, 1 do
      payload = call_tool("/action-mcp", "add_approval_request",
                          { room_id: @room.id, request_type: "decision", payload: { note: "db consistency check" } })
      assert_equal false, payload.dig("result", "isError")
      created = ApprovalRequest.order(:id).last
      assert_equal @room.id, created.room_id
      assert_equal "decision", created.request_type
      assert_equal "db consistency check", created.payload["note"]
    end
  end

  test "add_approve_request_with_message creates a message and approval request in the database" do
    assert_difference -> { Message.count }, 1 do
      assert_difference -> { ApprovalRequest.count }, 1 do
        payload = call_tool("/action-mcp", "add_approve_request_with_message",
                            { room_id: @room.id, body: "db check message", request_type: "action", payload: { note: "approval-added" } })
        assert_equal false, payload.dig("result", "isError")

        message = Message.order(:id).last
        approval = ApprovalRequest.order(:id).last
        assert_equal "db check message", message.plain_text_body
        assert_equal approval.id, message.approval_request.id
        assert_equal "action", approval.request_type
        assert_equal "approval-added", approval.payload["note"]
      end
    end
  end
end
