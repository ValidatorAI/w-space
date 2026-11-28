require "test_helper"

class Api::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"

    @user = User.create!(
      name: "Task API User",
      display_name: "Task API User",
      email_address: "task-api-user-#{SecureRandom.hex(4)}@example.com",
      password: "secret123456"
    )

    @project = Project.create!(
      id: rand(800_000..899_999),
      path: "/tmp/api-tasks-test-#{SecureRandom.hex(4)}",
      name: "Api Tasks Test Project"
    )
    @room = @project.rooms.create!(name: "Task room", type: "Rooms::Open", private: false, creator: @user)

    @task = Task.create!(
      project: @project,
      room: @room,
      description: "Write API",
      importance: 3,
      level: 2,
      dispatched: true,
      finished: false
    )

    @other_task = Task.create!(
      project: @project,
      description: "Another task",
      importance: 1,
      level: 1,
      dispatched: false,
      finished: true
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "lists tasks with optional filters and valid bearer token" do
    get api_tasks_url, params: { project_id: @project.id }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [@task.id, @other_task.id].sort, body["tasks"].map { |t| t["id"] }.sort

    get api_tasks_url, params: { room_id: @room.id, dispatched: true }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [@task.id], body["tasks"].map { |t| t["id"] }

    get api_tasks_url, params: { finished: false }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [@task.id], body["tasks"].map { |t| t["id"] }
  end

  test "creates, shows, updates, and deletes a task with valid bearer token" do
    post api_tasks_url,
      params: {
        project_id: @project.id,
        room_id: @room.id,
        description: "New task",
        importance: 5,
        level: 3,
        dispatched: false,
        finished: false
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New task", body["description"]

    task_id = body["id"]

    get api_task_url(task_id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :success

    patch api_task_url(task_id),
      params: { description: "Updated task", finished: true },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    updated = JSON.parse(response.body)
    assert_equal "Updated task", updated["description"]
    assert_equal true, updated["finished"]

    delete api_task_url(task_id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :no_content
  end

  test "PATCH dispatch_attempts=0 resets the task back to a dispatchable state" do
    task = AiTask.create!(
      project: @project,
      room: @room,
      description: "Stalled task",
      assigneee_profile: "planner",
      dispatched: true,
      finished: false,
      dispatch_attempts: 3,
      dispatch_error: "profile not found"
    )

    patch api_task_url(task.id),
      params: { dispatch_attempts: 0 },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    task.reload
    assert_equal 0, task.dispatch_attempts
    assert_equal false, task.dispatched
    assert_equal false, task.finished
    assert_nil task.dispatch_error
  end

  test "PATCH dispatch_attempts rejects invalid values and leaves the task untouched" do
    task = AiTask.create!(
      project: @project,
      room: @room,
      description: "Invalid attempts",
      assigneee_profile: "planner",
      dispatched: false,
      finished: false,
      dispatch_attempts: 1
    )

    [9, -1, "abc", ""].each do |invalid_value|
      patch api_task_url(task.id),
        params: { dispatch_attempts: invalid_value },
        headers: { "Authorization" => "Bearer test-token" }

      assert_response :unprocessable_entity
      task.reload
      assert_equal 1, task.dispatch_attempts
    end
  end

  test "rejects cost writes on finished tasks and preserves the closed state" do
    task = Task.create!(
      project: @project,
      room: @room,
      description: "Closed task",
      importance: 1,
      level: 1,
      token_used: 10,
      usd_used: 2.5,
      finished: true
    )

    patch api_task_url(task.id),
      params: { token_used: 500, usd_used: 25.0 },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/finished|frozen|cost/i, body["error"])

    task.reload
    assert_equal true, task.finished
    assert_equal 10, task.token_used
    assert_in_delta 2.5, task.usd_used, 0.01
  end

  test "partial PATCHes on finished tasks do not reopen them when finished is omitted" do
    task = Task.create!(
      project: @project,
      room: @room,
      description: "Closed task",
      importance: 1,
      level: 1,
      finished: true
    )

    patch api_task_url(task.id),
      params: { description: "Updated description" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    task.reload
    assert_equal "Updated description", task.description
    assert_equal true, task.finished
  end

  test "rolls task cost up through parent and grandparent tasks" do
    root = Task.create!(
      project: @project,
      room: @room,
      description: "Root task",
      importance: 1,
      level: 1,
      token_used: 2,
      usd_used: 2.0
    )
    child = Task.create!(
      project: @project,
      room: @room,
      description: "Child task",
      importance: 1,
      level: 1,
      parent_task: root,
      grand_parent_id: root.id,
      token_used: 1,
      usd_used: 1.0
    )
    leaf = Task.create!(
      project: @project,
      room: @room,
      description: "Leaf task",
      importance: 1,
      level: 1,
      parent_task: child,
      grand_parent_id: root.id,
      token_used: nil,
      usd_used: nil
    )

    post api_task_cost_url,
      params: { task_id: leaf.id, token_used: 1, usd_used: 1.0 },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    child.reload
    root.reload
    assert_equal 2, child.token_used
    assert_equal 2.0, child.usd_used
    assert_equal 3, root.token_used
    assert_equal 3.0, root.usd_used
  end

  test "lists all descendant tasks recursively" do
    root = Task.create!(project: @project, room: @room, description: "Root task", importance: 1, level: 1)
    child = Task.create!(project: @project, room: @room, description: "Child task", importance: 1, level: 1, parent_task: root)
    grandchild = Task.create!(project: @project, room: @room, description: "Grandchild task", importance: 1, level: 1, parent_task: child)
    sibling = Task.create!(project: @project, room: @room, description: "Sibling task", importance: 1, level: 1)

    get "/api/tasks/#{root.id}/children", headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [child.id, grandchild.id].sort, body["tasks"].map { |t| t["id"] }.sort
    assert_not_includes body["tasks"].map { |t| t["id"] }, sibling.id
  end

  test "lists all ancestor tasks recursively from child upward" do
    root = Task.create!(project: @project, room: @room, description: "Root task", importance: 1, level: 1)
    child = Task.create!(project: @project, room: @room, description: "Child task", importance: 1, level: 1, parent_task: root)
    grandchild = Task.create!(project: @project, room: @room, description: "Grandchild task", importance: 1, level: 1, parent_task: child)

    get "/api/tasks/#{grandchild.id}/parents", headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [child.id, root.id], body["tasks"].map { |t| t["id"] }
  end

  test "rejects requests without a bearer token" do
    get api_tasks_url
    assert_response :unauthorized
  end

  test "POST create rejects unknown assignee profile when Hermes profile check returns false" do
    Hermes::Client.any_instance.expects(:profile_exists?).with("nonexistent_xyz").returns(false)

    assert_no_difference -> { AiTask.count } do
      post api_tasks_url,
        params: {
          project_id: @project.id,
          room_id: @room.id,
          description: "Task with unknown assignee",
          assigneee_profile: "nonexistent_xyz"
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Unknown assignee profile: nonexistent_xyz", body["error"]
  end

  test "POST create accepts valid assignee profile when Hermes profile check returns true" do
    Hermes::Client.any_instance.expects(:profile_exists?).with("coder").returns(true)

    assert_difference -> { AiTask.count }, 1 do
      post api_tasks_url,
        params: {
          project_id: @project.id,
          room_id: @room.id,
          description: "Task with valid assignee",
          assigneee_profile: "coder"
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "coder", body["assigneee_profile"]
  end

  test "POST create falls back gracefully when Hermes gateway is unreachable" do
    Hermes::Client.any_instance.expects(:profile_exists?).with("planner").returns(nil)

    assert_difference -> { AiTask.count }, 1 do
      post api_tasks_url,
        params: {
          project_id: @project.id,
          room_id: @room.id,
          description: "Task with unreachable Hermes",
          assigneee_profile: "planner"
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "planner", body["assigneee_profile"]
  end

  test "PATCH update rejects unknown assignee profile when Hermes profile check returns false" do
    task = AiTask.create!(
      project: @project,
      room: @room,
      description: "Existing task",
      assigneee_profile: "original_profile"
    )

    Hermes::Client.any_instance.expects(:profile_exists?).with("bad_profile").returns(false)

    patch api_task_url(task.id),
      params: { assigneee_profile: "bad_profile" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Unknown assignee profile: bad_profile", body["error"]

    task.reload
    assert_equal "original_profile", task.assigneee_profile
  end

  test "PATCH update accepts valid assignee profile when Hermes profile check returns true" do
    task = AiTask.create!(
      project: @project,
      room: @room,
      description: "Existing task",
      assigneee_profile: "original_profile"
    )

    Hermes::Client.any_instance.expects(:profile_exists?).with("new_profile").returns(true)

    patch api_task_url(task.id),
      params: { assigneee_profile: "new_profile" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "new_profile", body["assigneee_profile"]

    task.reload
    assert_equal "new_profile", task.assigneee_profile
  end

  test "PATCH update without assignee profile does not query Hermes profile_exists?" do
    task = AiTask.create!(
      project: @project,
      room: @room,
      description: "Existing task",
      assigneee_profile: "original_profile"
    )

    Hermes::Client.any_instance.expects(:profile_exists?).never

    patch api_task_url(task.id),
      params: { description: "Renamed task" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Renamed task", body["description"]
    assert_equal "original_profile", body["assigneee_profile"]

    task.reload
    assert_equal "Renamed task", task.description
    assert_equal "original_profile", task.assigneee_profile
  end
end
