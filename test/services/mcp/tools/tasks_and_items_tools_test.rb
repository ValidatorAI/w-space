require "test_helper"

class TasksAndItemsToolsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @user = User.create!(name: "dave", display_name: "Dave Bowman", email_address: "dave@example.com", role: :member)
    @project = Project.create!(name: "Project Delta", path: "/path/delta", slug: "delta")
  end

  test "project todos lifecycle" do
    add_todo = Mcp::Registry.find_tool("add_project_todo", scope: :action)
    res = add_todo.call(project_id: @project.id, title: "Write tests")
    assert_equal false, res[:isError]

    todo = @project.todos.last
    assert_equal "Write tests", todo.title
    assert_not todo.completed?

    edit_todo = Mcp::Registry.find_tool("edit_project_todo", scope: :action)
    res_edit = edit_todo.call(todo_id: todo.id, completed: true)
    assert_equal false, res_edit[:isError]
    assert todo.reload.completed?
  end

  test "tasks and cost rollup" do
    create_task = Mcp::Registry.find_tool("create_task", scope: :task)
    res_parent = create_task.call(description: "Parent Task", project_id: @project.id)
    assert_equal false, res_parent[:isError]
    parent = Task.last

    res_child = create_task.call(description: "Child Task", parent_task_id: parent.id, project_id: @project.id)
    assert_equal false, res_child[:isError]
    child = Task.last

    cost_tool = Mcp::Registry.find_tool("task_cost", scope: :task)
    res_cost = cost_tool.call(task_id: child.id, token_used: 1000, usd_used: 0.05)
    assert_equal false, res_cost[:isError]

    assert_equal 1000, child.reload.token_used
    assert_in_delta 0.05, child.usd_used, 0.001

    assert_equal 1000, parent.reload.token_used
    assert_in_delta 0.05, parent.usd_used, 0.001
  end
end
