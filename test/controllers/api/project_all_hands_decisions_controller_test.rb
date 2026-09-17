require "test_helper"

class Api::ProjectAllHandsDecisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-all-hands-decisions-test", name: "Api Decisions Test Project")
    @decision = @project.project_all_hands_decisions.create!(
      title: "Migrate to SQLite 3 WAL mode",
      basis: "High read concurrency requirement",
      impact: "Zero lock contention observed",
      badge: "Approved",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all decisions for a project with a valid token" do
    inactive_decision = @project.project_all_hands_decisions.create!(
      title: "Deprecated decision",
      basis: "Old legacy context",
      impact: "None",
      badge: "Archived",
      active: false,
      position: 2
    )

    get api_project_project_all_hands_decisions_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @decision.id, inactive_decision.id ].sort, body["project_all_hands_decisions"].map { |item| item["id"] }.sort
  end

  test "filters decisions by active state with a valid token" do
    inactive_decision = @project.project_all_hands_decisions.create!(
      title: "Deprecated decision",
      basis: "Old legacy context",
      impact: "None",
      badge: "Archived",
      active: false,
      position: 2
    )

    get api_project_project_all_hands_decisions_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @decision.id ], body["project_all_hands_decisions"].map { |item| item["id"] }

    get api_project_project_all_hands_decisions_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_decision.id ], body["project_all_hands_decisions"].map { |item| item["id"] }
  end

  test "returns a single decision with a valid token" do
    get api_project_project_all_hands_decision_url(@project.id, @decision.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @decision.id, body["id"]
    assert_equal @decision.title, body["title"]
    assert_equal @decision.basis, body["basis"]
    assert_equal @decision.impact, body["impact"]
    assert_equal @decision.badge, body["badge"]
  end

  test "creates a decision with a valid token" do
    assert_difference -> { @project.project_all_hands_decisions.count }, 1 do
      post api_project_project_all_hands_decisions_url(@project.id),
        params: {
          title: "Adopt SolidQueue",
          basis: "Simplify background worker deployment",
          impact: "Eliminates Redis dependency for jobs",
          badge: "In Review",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Adopt SolidQueue", body["title"]
    assert_equal "Simplify background worker deployment", body["basis"]
    assert_equal "Eliminates Redis dependency for jobs", body["impact"]
    assert_equal "In Review", body["badge"]
  end

  test "updates a decision with a valid token" do
    patch api_project_project_all_hands_decision_url(@project.id, @decision.id),
      params: {
        title: "Migrate to SQLite 3 WAL mode with busy timeout",
        impact: "Zero write lock timeouts observed",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Migrate to SQLite 3 WAL mode with busy timeout", body["title"]
    assert_equal "Zero write lock timeouts observed", body["impact"]
    assert_equal false, body["active"]
  end

  test "deletes a decision with a valid token" do
    assert_difference -> { @project.project_all_hands_decisions.count }, -1 do
      delete api_project_project_all_hands_decision_url(@project.id, @decision.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.project_all_hands_decisions.find_by(id: @decision.id)
  end

  test "rejects requests without a token" do
    get api_project_project_all_hands_decisions_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_project_all_hands_decisions_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
