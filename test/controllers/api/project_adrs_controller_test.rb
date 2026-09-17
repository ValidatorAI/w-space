require "test_helper"

class Api::ProjectAdrsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-adrs-test", name: "Api ADRs Test Project")
    @adr = @project.adrs.create!(
      identifier: "ADR-001",
      title: "Use SQLite with WAL mode for primary persistence",
      decision_date: "2026-08-15",
      status: "accepted",
      file_path: "docs/adr/001-sqlite-wal.md",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all adrs for a project with a valid token" do
    inactive_adr = @project.adrs.create!(
      identifier: "ADR-000",
      title: "Proposed Mongo DB integration",
      status: "deprecated",
      active: false,
      position: 2
    )

    get api_project_adrs_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @adr.id, inactive_adr.id ].sort, body["adrs"].map { |a| a["id"] }.sort
  end

  test "filters adrs by active state with a valid token" do
    inactive_adr = @project.adrs.create!(
      identifier: "ADR-000",
      title: "Proposed Mongo DB integration",
      status: "deprecated",
      active: false,
      position: 2
    )

    get api_project_adrs_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @adr.id ], body["adrs"].map { |a| a["id"] }

    get api_project_adrs_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_adr.id ], body["adrs"].map { |a| a["id"] }
  end

  test "returns a single adr with a valid token" do
    get api_project_adr_url(@project.id, @adr.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @adr.id, body["id"]
    assert_equal @adr.identifier, body["identifier"]
    assert_equal @adr.title, body["title"]
    assert_equal @adr.status, body["status"]
    assert_equal @adr.file_path, body["file_path"]
  end

  test "creates an adr with a valid token" do
    assert_difference -> { @project.adrs.count }, 1 do
      post api_project_adrs_url(@project.id),
        params: {
          identifier: "ADR-002",
          title: "Adopt SolidQueue for Background Jobs",
          decision_date: "2026-09-01",
          status: "proposed",
          file_path: "docs/adr/002-solid-queue.md",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "ADR-002", body["identifier"]
    assert_equal "Adopt SolidQueue for Background Jobs", body["title"]
    assert_equal "proposed", body["status"]
  end

  test "updates an adr with a valid token" do
    patch api_project_adr_url(@project.id, @adr.id),
      params: {
        title: "Use SQLite with WAL mode and busy timeout",
        status: "accepted",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Use SQLite with WAL mode and busy timeout", body["title"]
    assert_equal false, body["active"]
  end

  test "deletes an adr with a valid token" do
    assert_difference -> { @project.adrs.count }, -1 do
      delete api_project_adr_url(@project.id, @adr.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.adrs.find_by(id: @adr.id)
  end

  test "rejects requests without a token" do
    get api_project_adrs_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_adrs_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
