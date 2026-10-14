require "test_helper"

class AttentionItemsToolsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @user = User.create!(name: "bob", display_name: "Bob Builder", email_address: "bob@example.com", role: :member)
    @project = Project.create!(name: "Project Beta", path: "/path/beta", slug: "beta")
  end

  test "creates, lists, and edits blockers attention item" do
    create_tool = Mcp::Registry.find_tool("add_blockers", scope: :action)
    assert create_tool.present?

    res = create_tool.call(
      title: "API Gateway Down",
      meta_text: "High severity",
      project_id: @project.id,
      user_id: @user.id
    )
    assert_equal false, res[:isError]

    item = AttentionItem.last
    assert_equal "blockers", item.category
    assert_equal "API Gateway Down", item.title
    assert_equal @project.id, item.project_id

    # List
    list_tool = Mcp::Registry.find_tool("blockers", scope: :read)
    res_list = list_tool.call(project_id: @project.id)
    assert_equal false, res_list[:isError]
    assert_includes res_list[:content].first[:text], "API Gateway Down"

    # Edit
    edit_tool = Mcp::Registry.find_tool("edit_blockers", scope: :action)
    res_edit = edit_tool.call(item_id: item.id, status: "resolved")
    assert_equal false, res_edit[:isError]
    assert item.reload.resolved?
  end

  test "deletes attention item" do
    item = AttentionItem.create!(category: "decisions_waiting", title: "Review contract", status: "pending")
    delete_tool = Mcp::Registry.find_tool("delete_attention_item", scope: :action)
    res = delete_tool.call(item_id: item.id)
    assert_equal false, res[:isError]
    assert_nil AttentionItem.find_by(id: item.id)
  end
end
