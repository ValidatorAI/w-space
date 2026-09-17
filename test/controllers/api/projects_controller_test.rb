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

  test "rejects index requests without a token" do
    get api_projects_url

    assert_response :unauthorized
  end
end
