require "test_helper"

class Api::ProjectKnowledgeItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-knowledge-items-test", name: "Api Knowledge Items Test Project")
    @item = @project.knowledge_items.create!(
      title: "Architecture Guidelines",
      description: "Service objects live in app/services and controllers stay slim.",
      badge: "Architecture",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all knowledge items for a project with a valid token" do
    inactive_item = @project.knowledge_items.create!(
      title: "Deprecated Guidelines",
      description: "Old guidelines from 2024.",
      badge: "Legacy",
      active: false,
      position: 2
    )

    get api_project_knowledge_items_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @item.id, inactive_item.id ].sort, body["knowledge_items"].map { |i| i["id"] }.sort
  end

  test "filters knowledge items by active state with a valid token" do
    inactive_item = @project.knowledge_items.create!(
      title: "Deprecated Guidelines",
      description: "Old guidelines from 2024.",
      badge: "Legacy",
      active: false,
      position: 2
    )

    get api_project_knowledge_items_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @item.id ], body["knowledge_items"].map { |i| i["id"] }

    get api_project_knowledge_items_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_item.id ], body["knowledge_items"].map { |i| i["id"] }
  end

  test "returns a single knowledge item with a valid token" do
    get api_project_knowledge_item_url(@project.id, @item.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @item.id, body["id"]
    assert_equal @item.title, body["title"]
    assert_equal @item.description, body["description"]
    assert_equal @item.badge, body["badge"]
  end

  test "creates a knowledge item with a valid token" do
    assert_difference -> { @project.knowledge_items.count }, 1 do
      post api_project_knowledge_items_url(@project.id),
        params: {
          title: "CI/CD Pipeline",
          description: "All PRs run unit and integration tests.",
          badge: "DevOps",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "CI/CD Pipeline", body["title"]
    assert_equal "DevOps", body["badge"]
  end

  test "updates a knowledge item with a valid token" do
    patch api_project_knowledge_item_url(@project.id, @item.id),
      params: {
        title: "Architecture Guidelines (Updated)",
        description: "New architecture guidelines updated for 2026.",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Architecture Guidelines (Updated)", body["title"]
    assert_equal false, body["active"]
  end

  test "deletes a knowledge item with a valid token" do
    assert_difference -> { @project.knowledge_items.count }, -1 do
      delete api_project_knowledge_item_url(@project.id, @item.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.knowledge_items.find_by(id: @item.id)
  end

  test "rejects requests without a token" do
    get api_project_knowledge_items_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_knowledge_items_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
