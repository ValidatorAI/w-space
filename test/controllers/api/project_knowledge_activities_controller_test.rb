require "test_helper"

class Api::ProjectKnowledgeActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-knowledge-activities-test", name: "Api Knowledge Activities Test Project")
    @activity = @project.knowledge_activities.create!(
      actor_name: "Alice",
      actor_color: "#3b82f6",
      action_text: "Updated [[Infrastructure Routing]]",
      target_path: "docs/infra.md",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all knowledge activities for a project with a valid token" do
    inactive_activity = @project.knowledge_activities.create!(
      actor_name: "Bob",
      action_text: "Deleted old draft",
      active: false,
      position: 2
    )

    get api_project_knowledge_activities_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @activity.id, inactive_activity.id ].sort, body["knowledge_activities"].map { |a| a["id"] }.sort
  end

  test "filters knowledge activities by active state with a valid token" do
    inactive_activity = @project.knowledge_activities.create!(
      actor_name: "Bob",
      action_text: "Deleted old draft",
      active: false,
      position: 2
    )

    get api_project_knowledge_activities_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @activity.id ], body["knowledge_activities"].map { |a| a["id"] }

    get api_project_knowledge_activities_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_activity.id ], body["knowledge_activities"].map { |a| a["id"] }
  end

  test "returns a single knowledge activity with a valid token" do
    get api_project_knowledge_activity_url(@project.id, @activity.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @activity.id, body["id"]
    assert_equal @activity.actor_name, body["actor_name"]
    assert_equal @activity.action_text, body["action_text"]
    assert_equal @activity.target_path, body["target_path"]
  end

  test "creates a knowledge activity with a valid token" do
    assert_difference -> { @project.knowledge_activities.count }, 1 do
      post api_project_knowledge_activities_url(@project.id),
        params: {
          actor_name: "Charlie",
          actor_color: "#10b981",
          action_text: "Added [[ADR-002]]",
          target_path: "docs/adr/002.md",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Charlie", body["actor_name"]
    assert_equal "Added [[ADR-002]]", body["action_text"]
  end

  test "updates a knowledge activity with a valid token" do
    patch api_project_knowledge_activity_url(@project.id, @activity.id),
      params: {
        action_text: "Updated [[Infrastructure Routing (v2)]]",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated [[Infrastructure Routing (v2)]]", body["action_text"]
    assert_equal false, body["active"]
  end

  test "deletes a knowledge activity with a valid token" do
    assert_difference -> { @project.knowledge_activities.count }, -1 do
      delete api_project_knowledge_activity_url(@project.id, @activity.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.knowledge_activities.find_by(id: @activity.id)
  end

  test "rejects requests without a token" do
    get api_project_knowledge_activities_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_knowledge_activities_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
