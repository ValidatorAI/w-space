require "test_helper"

class Api::ProjectAllHandsActionItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-all-hands-action-items-test", name: "Api Action Items Test Project")
    @action_item = @project.project_all_hands_action_items.create!(
      title: "Complete DB benchmark suite",
      assignee_name: "Alice",
      due_date: "2026-09-15",
      completed: false,
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all action items for a project with a valid token" do
    inactive_item = @project.project_all_hands_action_items.create!(
      title: "Old archived action item",
      assignee_name: "Bob",
      due_date: "2026-08-01",
      completed: true,
      active: false,
      position: 2
    )

    get api_project_project_all_hands_action_items_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @action_item.id, inactive_item.id ].sort, body["project_all_hands_action_items"].map { |item| item["id"] }.sort
  end

  test "filters action items by active state with a valid token" do
    inactive_item = @project.project_all_hands_action_items.create!(
      title: "Old archived action item",
      assignee_name: "Bob",
      due_date: "2026-08-01",
      completed: true,
      active: false,
      position: 2
    )

    get api_project_project_all_hands_action_items_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @action_item.id ], body["project_all_hands_action_items"].map { |item| item["id"] }

    get api_project_project_all_hands_action_items_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_item.id ], body["project_all_hands_action_items"].map { |item| item["id"] }
  end

  test "returns a single action item with a valid token" do
    get api_project_project_all_hands_action_item_url(@project.id, @action_item.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @action_item.id, body["id"]
    assert_equal @action_item.title, body["title"]
    assert_equal @action_item.assignee_name, body["assignee_name"]
    assert_equal @action_item.due_date, body["due_date"]
    assert_equal @action_item.completed, body["completed"]
  end

  test "creates an action item with a valid token" do
    assert_difference -> { @project.project_all_hands_action_items.count }, 1 do
      post api_project_project_all_hands_action_items_url(@project.id),
        params: {
          title: "Deploy release v2.0",
          assignee_name: "Charlie",
          due_date: "2026-09-30",
          completed: false,
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Deploy release v2.0", body["title"]
    assert_equal "Charlie", body["assignee_name"]
    assert_equal "2026-09-30", body["due_date"]
    assert_equal false, body["completed"]
  end

  test "updates an action item with a valid token" do
    patch api_project_project_all_hands_action_item_url(@project.id, @action_item.id),
      params: {
        title: "Complete DB benchmark suite (Extended)",
        completed: true,
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Complete DB benchmark suite (Extended)", body["title"]
    assert_equal true, body["completed"]
    assert_not_nil body["completed_at"]
    assert_equal false, body["active"]
  end

  test "deletes an action item with a valid token" do
    assert_difference -> { @project.project_all_hands_action_items.count }, -1 do
      delete api_project_project_all_hands_action_item_url(@project.id, @action_item.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.project_all_hands_action_items.find_by(id: @action_item.id)
  end

  test "rejects requests without a token" do
    get api_project_project_all_hands_action_items_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_project_all_hands_action_items_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
