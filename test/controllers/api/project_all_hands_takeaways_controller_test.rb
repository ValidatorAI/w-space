require "test_helper"

class Api::ProjectAllHandsTakeawaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-all-hands-takeaways-test", name: "Api Takeaways Test Project")
    @takeaway = @project.project_all_hands_takeaways.create!(
      category: "Performance",
      content: "Latency was reduced by 40%.",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all takeaways for a project with a valid token" do
    inactive_takeaway = @project.project_all_hands_takeaways.create!(
      category: "Operations",
      content: "Old stale note.",
      active: false,
      position: 2
    )

    get api_project_project_all_hands_takeaways_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @takeaway.id, inactive_takeaway.id ].sort, body["project_all_hands_takeaways"].map { |item| item["id"] }.sort
  end

  test "filters takeaways by active state with a valid token" do
    inactive_takeaway = @project.project_all_hands_takeaways.create!(
      category: "Operations",
      content: "Old stale note.",
      active: false,
      position: 2
    )

    get api_project_project_all_hands_takeaways_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @takeaway.id ], body["project_all_hands_takeaways"].map { |item| item["id"] }

    get api_project_project_all_hands_takeaways_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_takeaway.id ], body["project_all_hands_takeaways"].map { |item| item["id"] }
  end

  test "returns a single takeaway with a valid token" do
    get api_project_project_all_hands_takeaway_url(@project.id, @takeaway.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @takeaway.id, body["id"]
    assert_equal @takeaway.category, body["category"]
    assert_equal @takeaway.content, body["content"]
  end

  test "creates a takeaway with a valid token" do
    assert_difference -> { @project.project_all_hands_takeaways.count }, 1 do
      post api_project_project_all_hands_takeaways_url(@project.id),
        params: {
          category: "Culture",
          content: "Team shipped two release trains ahead of plan.",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Culture", body["category"]
    assert_equal "Team shipped two release trains ahead of plan.", body["content"]
  end

  test "updates a takeaway with a valid token" do
    patch api_project_project_all_hands_takeaway_url(@project.id, @takeaway.id),
      params: {
        category: "Performance",
        content: "Latency improved by 60%.",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Latency improved by 60%.", body["content"]
    assert_equal false, body["active"]
  end

  test "deletes a takeaway with a valid token" do
    assert_difference -> { @project.project_all_hands_takeaways.count }, -1 do
      delete api_project_project_all_hands_takeaway_url(@project.id, @takeaway.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.project_all_hands_takeaways.find_by(id: @takeaway.id)
  end

  test "rejects requests without a token" do
    get api_project_project_all_hands_takeaways_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_project_all_hands_takeaways_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
