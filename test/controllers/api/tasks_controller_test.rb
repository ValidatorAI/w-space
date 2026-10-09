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
      added_to_kanban: true,
      runned: false
    )

    @other_task = Task.create!(
      project: @project,
      description: "Another task",
      importance: 1,
      level: 1,
      added_to_kanban: false,
      runned: true
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

    get api_tasks_url, params: { room_id: @room.id, added_to_kanban: true }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [@task.id], body["tasks"].map { |t| t["id"] }

    get api_tasks_url, params: { runned: false }, headers: { "Authorization" => "Bearer test-token" }
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
        added_to_kanban: false,
        runned: false
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New task", body["description"]

    task_id = body["id"]

    get api_task_url(task_id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :success

    patch api_task_url(task_id),
      params: { description: "Updated task", runned: true },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    updated = JSON.parse(response.body)
    assert_equal "Updated task", updated["description"]
    assert_equal true, updated["runned"]

    delete api_task_url(task_id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :no_content
  end

  test "rejects requests without a bearer token" do
    get api_tasks_url
    assert_response :unauthorized
  end
end
