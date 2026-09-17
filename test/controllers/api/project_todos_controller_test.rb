require "test_helper"

class Api::ProjectTodosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(
      id: rand(800_000..899_999),
      path: "/tmp/api-project-todos-test-#{SecureRandom.hex(4)}",
      name: "Api Todos Test Project"
    )
    @todo = @project.todos.create!(
      title: "Migrate database indices",
      meta_text: "High priority",
      completed: false,
      position: 1,
      created_at: Time.zone.parse("2026-09-01 12:00:00")
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all todos for a project with a valid token" do
    completed_item = @project.todos.create!(
      title: "Old Completed Task",
      completed: true,
      completed_at: Time.current,
      position: 2,
      created_at: Time.zone.parse("2026-08-15 10:00:00")
    )

    get api_project_todos_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @todo.id, completed_item.id ].sort, body["project_todos"].map { |t| t["id"] }.sort
  end

  test "filters todos by completed and active state with a valid token" do
    completed_item = @project.todos.create!(
      title: "Old Completed Task",
      completed: true,
      completed_at: Time.current,
      position: 2
    )

    get api_project_todos_url(@project.id, completed: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ completed_item.id ], body["project_todos"].map { |t| t["id"] }

    get api_project_todos_url(@project.id, completed: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ @todo.id ], body["project_todos"].map { |t| t["id"] }

    get api_project_todos_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ @todo.id ], body["project_todos"].map { |t| t["id"] }
  end

  test "filters todos by created_at range with a valid token" do
    earlier_item = @project.todos.create!(
      title: "Early Todo",
      created_at: Time.zone.parse("2026-08-01 10:00:00")
    )
    later_item = @project.todos.create!(
      title: "Later Todo",
      created_at: Time.zone.parse("2026-09-10 10:00:00")
    )

    # Filter created_at > 2026-08-15 and created_at < 2026-09-05 (only matches @todo)
    get api_project_todos_url(@project.id, created_at_gt: "2026-08-15T00:00:00Z", created_at_lt: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @todo.id ], body["project_todos"].map { |t| t["id"] }

    # Test using from and to aliases
    get api_project_todos_url(@project.id, from: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ later_item.id ], body["project_todos"].map { |t| t["id"] }
  end

  test "returns a single todo with a valid token" do
    get api_project_todo_url(@project.id, @todo.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @todo.id, body["id"]
    assert_equal @todo.title, body["title"]
    assert_equal @todo.meta_text, body["meta_text"]
    assert_equal false, body["completed"]
  end

  test "creates a todo with a valid token" do
    assert_difference -> { @project.todos.count }, 1 do
      post api_project_todos_url(@project.id),
        params: {
          title: "Upgrade Ruby to 3.4",
          meta_text: "Infra sprint",
          completed: false,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Upgrade Ruby to 3.4", body["title"]
    assert_equal "Infra sprint", body["meta_text"]
    assert_equal false, body["completed"]
  end

  test "updates a todo with a valid token" do
    patch api_project_todo_url(@project.id, @todo.id),
      params: {
        title: "Migrate database indices (Completed)",
        completed: true
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Migrate database indices (Completed)", body["title"]
    assert_equal true, body["completed"]
    assert_not_nil body["completed_at"]
  end

  test "deletes a todo with a valid token" do
    assert_difference -> { @project.todos.count }, -1 do
      delete api_project_todo_url(@project.id, @todo.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.todos.find_by(id: @todo.id)
  end

  test "rejects requests without a token" do
    get api_project_todos_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_todos_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
