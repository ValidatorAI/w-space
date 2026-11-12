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

  test "task context fields are split between proposal and actual execution" do
    create_task = Mcp::Registry.find_tool("create_task", scope: :task)
    create_result = create_task.call(
      description: "Ship reporting",
      project_id: @project.id,
      proposed_task_context: "Initial proposal context"
    )
    assert_equal false, create_result[:isError]

    task = Task.last
    assert_equal "Initial proposal context", task.proposed_task_context
    assert_nil task.actual_task_context

    update_task = Mcp::Registry.find_tool("update_task", scope: :task)
    update_result = update_task.call(
      task_id: task.id,
      actual_task_context: "Final execution context"
    )
    assert_equal false, update_result[:isError]

    task.reload
    assert_nil task.proposed_task_context
    assert_equal "Final execution context", task.actual_task_context
  end

  test "task rows persist external task and input event references" do
    create_task = Mcp::Registry.find_tool("create_task", scope: :task)
    create_result = create_task.call(
      description: "Follow up on gated approval",
      project_id: @project.id,
      task_id: 987,
      input_event_entity_id: 654
    )
    assert_equal false, create_result[:isError]

    task = Task.last
    assert_equal 987, task.task_id
    assert_equal 654, task.input_event_entity_id

    update_task = Mcp::Registry.find_tool("update_task", scope: :task)
    update_result = update_task.call(
      task_id: task.id,
      input_event_entity_id: 777
    )
    assert_equal false, update_result[:isError]

    task.reload
    assert_equal 777, task.input_event_entity_id
  end

  test "create_ai_task rejects unknown arguments and accepts assignee alias" do
    create_task = Mcp::Registry.find_tool("create_ai_task", scope: :task)

    rejected = create_task.call(
      description: "Reject bad payload",
      project_id: @project.id,
      profile_name: "ghost-agent"
    )
    assert_equal true, rejected[:isError]
    assert_match(/profile_name|Unknown argument|unexpected/i, rejected[:content].first[:text])

    accepted = create_task.call(
      description: "Alias assignee",
      project_id: @project.id,
      assignee_profile: "agent-42"
    )
    assert_equal false, accepted[:isError]
    assert_equal "agent-42", AiTask.last.assigneee_profile
  end

  test "create_ai_task resolves project slug and rejects invalid project or room refs" do
    room = Room.create!(name: "Ops room", project: @project, type: "Rooms::Open", private: false, creator: @user)
    create_task = Mcp::Registry.find_tool("create_ai_task", scope: :task)

    accepted = create_task.call(
      description: "Task with project slug",
      project_id: @project.slug,
      room_id: room.id.to_s
    )
    assert_equal false, accepted[:isError]
    task = AiTask.last
    assert_equal @project.id, task.project_id
    assert_equal room.id, task.room_id

    invalid_project = create_task.call(
      description: "Task with missing project",
      project_id: "not-a-project",
      room_id: room.id
    )
    assert_equal true, invalid_project[:isError]
    assert_match(/Project not found|project_id/i, invalid_project[:content].first[:text])

    invalid_room = create_task.call(
      description: "Task with missing room",
      project_id: @project.id,
      room_id: 9_999_999
    )
    assert_equal true, invalid_room[:isError]
    assert_match(/Room not found|room_id/i, invalid_room[:content].first[:text])
  end

  test "create_ai_task resolves string room names to the correct room" do
    room = Room.create!(name: "Ops room", project: @project, type: "Rooms::Open", private: false, creator: @user)
    create_task = Mcp::Registry.find_tool("create_ai_task", scope: :task)

    accepted = create_task.call(
      description: "Task with room-by-name",
      project_id: @project.id,
      room_id: "Ops room"
    )

    assert_equal false, accepted[:isError]
    assert_equal room.id, AiTask.last.room_id
  end

  test "create_ai_task keeps task rows for blank assignee and creates warning attention item" do
    create_task = Mcp::Registry.find_tool("create_ai_task", scope: :task)

    result = create_task.call(
      description: "Task without assignee",
      project_id: @project.id,
      assignee_profile: "   "
    )

    assert_equal false, result[:isError]
    payload = JSON.parse(result[:content].first[:text])
    assert_equal "Task without assignee", payload["description"]
    assert_equal "missing_assignee_profile", payload["warning"]["code"]
    assert_equal "blockers", payload["warning"]["attention_item"]["category"]
    assert_equal @project.id, payload["warning"]["attention_item"]["project_id"]
    assert_equal 1, AttentionItem.where(project_id: @project.id, category: "blockers", status: "pending").count
  end
end
