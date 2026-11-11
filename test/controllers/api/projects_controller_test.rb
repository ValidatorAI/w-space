require "test_helper"

class Api::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-projects-test", name: "Api Test Project")
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns project by id with a valid token" do
    get api_project_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @project.id, body["id"]
    assert_equal @project.slug, body["slug"]
  end

  test "returns project by slug with a valid token" do
    get api_project_url(@project.slug), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal @project.id, JSON.parse(response.body)["id"]
  end

  test "rejects requests without a token" do
    get api_project_url(@project.id)

    assert_response :unauthorized
  end

  test "rejects requests with an invalid token" do
    get api_project_url(@project.id), headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "returns not found for an unknown project" do
    get api_project_url("does-not-exist"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns all projects with a valid token" do
    get api_projects_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body.map { |project| project["id"] }, @project.id
  end

  test "creates a project and emits the project_created event" do
    post api_projects_url,
         params: {
           name: "New API Project",
           path: "/tmp/api-project-create-test",
           description: "Created through the API",
           private: true,
           short_code: "NAPI",
           actor_user_id: users(:david).id
         },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New API Project", body["name"]
    assert_equal "api-project-create-test", body["slug"]
    assert_equal "NAPI", body["short_code"]
    assert_equal true, body["created"]

    event = OutputEvent.order(:id).last
    assert_equal "project_created", event.event_type
    assert_equal users(:david).id, event.event_data["actor"]["id"]
  end

  test "updates an existing project and emits the project_updated event" do
    patch api_project_url(@project.id),
          params: {
            name: "Updated Project Name",
            description: "Refreshed via API",
            private: true,
            short_code: "UPD",
            budget_total: 9000,
            budget_spent: 2500,
            current_phase: "Phase 2"
          },
          headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated Project Name", body["name"]
    assert_equal "Refreshed via API", body["description"]
    assert_equal "UPD", body["short_code"]
    assert_equal 9000, body["budget_total"]
    assert_equal 2500, body["budget_spent"]
    assert_equal "Phase 2", body["current_phase"]

    event = OutputEvent.order(:id).last
    assert_equal "project_updated", event.event_type
    assert_includes event.event_data["changed_fields"], "name"
  end

  test "returns the existing project for duplicate create requests" do
    path = "/tmp/api-project-duplicate-test"
    Project.create!(path: path, name: "Original duplicate test project")

    assert_no_difference("Project.count") do
      post api_projects_url,
           params: {
             path: path,
             name: "Duplicate project request"
           },
           headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal false, body["created"]
    assert_equal path, body["path"]
    assert_equal 1, Project.where(path: path).count
  end

  test "blocks project deletion while pending approvals remain" do
    room = @project.rooms.create!(type: "Rooms::Open", name: "Approval Room", creator: users(:david))
    room.approval_requests.create!(request_type: "deploy", payload: { "env" => "prod" }, status: :pending)

    delete api_project_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :conflict
    body = JSON.parse(response.body)
    assert_equal "open approvals exist", body["error"]
    assert_equal 1, body["pending_count"]
    assert @project.reload.persisted?
  end

  test "allows project deletion after pending approvals are resolved" do
    room = @project.rooms.create!(type: "Rooms::Open", name: "Approval Room", creator: users(:david))
    approval = room.approval_requests.create!(request_type: "deploy", payload: { "env" => "prod" }, status: :pending)
    approval.update!(status: :approved)

    delete api_project_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :no_content
    assert_nil Project.find_by(id: @project.id)
  end

  test "rejects index requests without a token" do
    get api_projects_url

    assert_response :unauthorized
  end
end
