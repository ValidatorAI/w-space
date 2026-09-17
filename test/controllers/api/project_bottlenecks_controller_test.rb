require "test_helper"

class Api::ProjectBottlenecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(
      id: rand(900_000..999_999),
      path: "/tmp/api-project-bottlenecks-test-#{SecureRandom.hex(4)}",
      name: "Api Bottlenecks Test Project"
    )
    @bottleneck = @project.bottlenecks.create!(
      title: "Obsidian Vault Indexing Timeout",
      description: "Large attachments slow down sync",
      severity: "active",
      position: 1,
      created_at: Time.zone.parse("2026-09-01 12:00:00")
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all bottlenecks for a project with a valid token" do
    resolved_item = @project.bottlenecks.create!(
      title: "Resolved DB Lock",
      description: "Resolved earlier",
      severity: "resolved",
      resolved_at: Time.current,
      position: 2,
      created_at: Time.zone.parse("2026-08-15 10:00:00")
    )

    get api_project_bottlenecks_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @bottleneck.id, resolved_item.id ].sort, body["project_bottlenecks"].map { |b| b["id"] }.sort
  end

  test "filters bottlenecks by active state with a valid token" do
    resolved_item = @project.bottlenecks.create!(
      title: "Resolved DB Lock",
      description: "Resolved earlier",
      severity: "resolved",
      resolved_at: Time.current,
      position: 2
    )

    get api_project_bottlenecks_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @bottleneck.id ], body["project_bottlenecks"].map { |b| b["id"] }

    get api_project_bottlenecks_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ resolved_item.id ], body["project_bottlenecks"].map { |b| b["id"] }
  end

  test "filters bottlenecks by created_at range with a valid token" do
    earlier_item = @project.bottlenecks.create!(
      title: "Early Bottleneck",
      created_at: Time.zone.parse("2026-08-01 10:00:00")
    )
    later_item = @project.bottlenecks.create!(
      title: "Later Bottleneck",
      created_at: Time.zone.parse("2026-09-10 10:00:00")
    )

    # Filter created_at > 2026-08-15 and created_at < 2026-09-05 (should only include @bottleneck from 2026-09-01)
    get api_project_bottlenecks_url(@project.id, created_at_gt: "2026-08-15T00:00:00Z", created_at_lt: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @bottleneck.id ], body["project_bottlenecks"].map { |b| b["id"] }

    # Test using from and to aliases
    get api_project_bottlenecks_url(@project.id, from: "2026-09-05T00:00:00Z"),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ later_item.id ], body["project_bottlenecks"].map { |b| b["id"] }
  end

  test "returns a single bottleneck with a valid token" do
    get api_project_bottleneck_url(@project.id, @bottleneck.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @bottleneck.id, body["id"]
    assert_equal @bottleneck.title, body["title"]
    assert_equal @bottleneck.description, body["description"]
    assert_equal @bottleneck.severity, body["severity"]
  end

  test "creates a bottleneck with a valid token" do
    assert_difference -> { @project.bottlenecks.count }, 1 do
      post api_project_bottlenecks_url(@project.id),
        params: {
          title: "CI test suite flaky timeout",
          description: "Integration tests take > 2 minutes",
          severity: "warning",
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "CI test suite flaky timeout", body["title"]
    assert_equal "warning", body["severity"]
  end

  test "updates a bottleneck with a valid token" do
    patch api_project_bottleneck_url(@project.id, @bottleneck.id),
      params: {
        title: "Obsidian Vault Indexing Timeout (Resolved)",
        resolved: true
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Obsidian Vault Indexing Timeout (Resolved)", body["title"]
    assert_equal "resolved", body["severity"]
    assert_not_nil body["resolved_at"]
  end

  test "deletes a bottleneck with a valid token" do
    assert_difference -> { @project.bottlenecks.count }, -1 do
      delete api_project_bottleneck_url(@project.id, @bottleneck.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.bottlenecks.find_by(id: @bottleneck.id)
  end

  test "rejects requests without a token" do
    get api_project_bottlenecks_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_bottlenecks_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
