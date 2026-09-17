require "test_helper"

class Api::ProjectMilestonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(
      id: rand(700_000..799_999),
      path: "/tmp/api-project-milestones-test-#{SecureRandom.hex(4)}",
      name: "Api Milestones Test Project"
    )
    @milestone = @project.project_milestones.create!(
      title: "Discovery & framework alignment",
      description: "Initial architecture validated",
      icon: "✅",
      active: true,
      position: 1,
      created_at: Time.zone.parse("2026-09-01 12:00:00")
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all milestones for a project with a valid token" do
    inactive_item = @project.project_milestones.create!(
      title: "Old Deprecated Milestone",
      description: "Archived roadmap phase",
      icon: "📦",
      active: false,
      position: 2,
      created_at: Time.zone.parse("2026-08-15 10:00:00")
    )

    get api_project_milestones_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @milestone.id, inactive_item.id ].sort, body["project_milestones"].map { |m| m["id"] }.sort
  end

  test "filters milestones by active state with a valid token" do
    inactive_item = @project.project_milestones.create!(
      title: "Old Deprecated Milestone",
      description: "Archived roadmap phase",
      icon: "📦",
      active: false,
      position: 2
    )

    get api_project_milestones_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @milestone.id ], body["project_milestones"].map { |m| m["id"] }

    get api_project_milestones_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_item.id ], body["project_milestones"].map { |m| m["id"] }
  end

  test "filters milestones by created_at range with a valid token" do
    earlier_item = @project.project_milestones.create!(
      title: "Early Milestone",
      created_at: Time.zone.parse("2026-08-01 10:00:00")
    )
    later_item = @project.project_milestones.create!(
      title: "Later Milestone",
      created_at: Time.zone.parse("2026-09-10 10:00:00")
    )

    # Filter created_at > 2026-08-15 and created_at < 2026-09-05 (only matches @milestone)
    get api_project_milestones_url(@project.id, created_at_gt: "2026-08-15T00:00:00Z", created_at_lt: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @milestone.id ], body["project_milestones"].map { |m| m["id"] }

    # Test using from and to aliases
    get api_project_milestones_url(@project.id, from: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ later_item.id ], body["project_milestones"].map { |m| m["id"] }
  end

  test "returns a single milestone with a valid token" do
    get api_project_milestone_url(@project.id, @milestone.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @milestone.id, body["id"]
    assert_equal @milestone.title, body["title"]
    assert_equal @milestone.description, body["description"]
    assert_equal @milestone.icon, body["icon"]
    assert_equal true, body["active"]
  end

  test "creates a milestone with a valid token" do
    assert_difference -> { @project.project_milestones.count }, 1 do
      post api_project_milestones_url(@project.id),
        params: {
          title: "Production launch",
          description: "Full public rollout",
          icon: "🚀",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Production launch", body["title"]
    assert_equal "🚀", body["icon"]
    assert_equal true, body["active"]
  end

  test "updates a milestone with a valid token" do
    patch api_project_milestone_url(@project.id, @milestone.id),
      params: {
        title: "Discovery & framework alignment (Completed)",
        icon: "🎉",
        active: false
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Discovery & framework alignment (Completed)", body["title"]
    assert_equal "🎉", body["icon"]
    assert_equal false, body["active"]
  end

  test "deletes a milestone with a valid token" do
    assert_difference -> { @project.project_milestones.count }, -1 do
      delete api_project_milestone_url(@project.id, @milestone.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.project_milestones.find_by(id: @milestone.id)
  end

  test "rejects requests without a token" do
    get api_project_milestones_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_milestones_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
