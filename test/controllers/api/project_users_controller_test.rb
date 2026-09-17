require "test_helper"

class Api::ProjectUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-users-test", name: "Api Project Users Test Project")
    @user = users(:david)
    @project.project_users.create!(user: @user)
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all project users with a valid token" do
    other_user = users(:jason)
    @project.project_users.create!(user: other_user)

    get api_project_project_users_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @user.id, other_user.id ].sort, body["project_users"].map { |member| member["id"] }.sort
  end

  test "returns a single project user with a valid token" do
    get api_project_project_user_url(@project.id, @user.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @user.id, body["id"]
    assert_equal @user.name, body["name"]
  end

  test "returns not found for a missing project" do
    get api_project_project_users_url(-1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for a missing project user" do
    get api_project_project_user_url(@project.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "rejects requests without a token" do
    get api_project_project_users_url(@project.id)

    assert_response :unauthorized
  end
end
