require "test_helper"

class MessagingAndApprovalsToolsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @user = User.create!(name: "carol", display_name: "Carol Danvers", email_address: "carol@example.com", role: :member)
    @project = Project.create!(name: "Project Gamma", path: "/path/gamma", slug: "gamma")
    @room = Rooms::Open.create!(name: "General Room", creator: @user, project: @project)
  end

  test "message lifecycle and loading message" do
    add_msg = Mcp::Registry.find_tool("add_message", scope: :action)
    res = add_msg.call(room_id: @room.id, user_id: @user.id, body: "Hello from MCP test")
    assert_equal false, res[:isError]

    msg = @room.messages.last
    assert_equal "Hello from MCP test", msg.plain_text_body

    # Loading message
    add_loading = Mcp::Registry.find_tool("add_loading_message", scope: :action)
    res_load = add_loading.call(room_id: @room.id, user_id: @user.id, body: "Thinking...")
    assert_equal false, res_load[:isError]
    load_msg = @room.messages.last
    assert_includes load_msg.plain_text_body, ":spin: Thinking..."

    # Edit loading message
    edit_loading = Mcp::Registry.find_tool("edit_loading_message", scope: :action)
    res_edit = edit_loading.call(message_id: load_msg.id, body: "Almost done...")
    assert_equal false, res_edit[:isError]
    assert_includes load_msg.reload.plain_text_body, ":spin: Almost done..."

    # Delete loading message
    del_loading = Mcp::Registry.find_tool("delete_loading_message", scope: :action)
    res_del = del_loading.call(message_id: load_msg.id)
    assert_equal false, res_del[:isError]
    assert_nil Message.find_by(id: load_msg.id)
  end

  test "approval request lifecycle" do
    add_appr = Mcp::Registry.find_tool("add_approval_request", scope: :action)
    res = add_appr.call(room_id: @room.id, request_type: "deploy", payload: { env: "prod" })
    assert_equal false, res[:isError]

    appr = @room.approval_requests.last
    assert_equal "deploy", appr.request_type
    assert appr.pending?

    # Decide
    decide_tool = Mcp::Registry.find_tool("add_decision_message", scope: :action)
    res_decide = decide_tool.call(approval_request_id: appr.id, decision: "approve", note: "Approved by lead")
    assert_equal false, res_decide[:isError]
    assert appr.reload.approved?
  end
end
