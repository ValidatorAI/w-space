require "test_helper"

class Api::RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-rooms-test", name: "Api Rooms Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns rooms for a project with a valid token" do
    get api_project_rooms_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body.map { |room| room["id"] }, @room.id
  end

  test "returns rooms for a project looked up by slug" do
    get api_project_rooms_url(@project.slug), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_includes JSON.parse(response.body).map { |room| room["id"] }, @room.id
  end

  test "rejects requests without a token" do
    get api_project_rooms_url(@project.id)

    assert_response :unauthorized
  end

  test "legacy api routes are disabled when DISABLE_API_ROUTES is true" do
    previous = ENV["DISABLE_API_ROUTES"]
    ENV["DISABLE_API_ROUTES"] = "true"
    Rails.application.reload_routes!

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/api/projects/#{@project.id}/rooms")
    end
  ensure
    ENV["DISABLE_API_ROUTES"] = previous || "false"
    Rails.application.reload_routes!
  end

  test "returns not found for an unknown project" do
    get api_project_rooms_url("does-not-exist"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns a single room with a valid token" do
    get api_project_room_url(@project.id, @room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal @room.id, JSON.parse(response.body)["id"]
  end

  test "rejects show requests without a token" do
    get api_project_room_url(@project.id, @room.id)

    assert_response :unauthorized
  end

  test "returns not found for an unknown room" do
    get api_project_room_url(@project.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found when room belongs to a different project" do
    other_project = Project.create!(path: "/tmp/api-rooms-test-other", name: "Other Project")

    get api_project_room_url(other_project.id, @room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns threads (child rooms) of a room with a valid token" do
    thread = @project.rooms.create!(type: "Rooms::Open", name: "Thread 1", creator: users(:david), parent_id: @room.id)
    other_room = @project.rooms.create!(type: "Rooms::Open", name: "Unrelated", creator: users(:david))

    get threads_api_project_room_url(@project.id, @room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    ids = JSON.parse(response.body).map { |room| room["id"] }
    assert_equal [ thread.id ], ids
    assert_not_includes ids, other_room.id
  end

  test "rejects threads requests without a token" do
    get threads_api_project_room_url(@project.id, @room.id)

    assert_response :unauthorized
  end

  test "returns not found for threads of an unknown room" do
    get threads_api_project_room_url(@project.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "finds a room id via fuzzy name search with a valid token" do
    marketing_room = @project.rooms.create!(type: "Rooms::Open", name: "Marketing Launch", creator: users(:david))
    @project.rooms.create!(type: "Rooms::Open", name: "Unrelated Room", creator: users(:david))

    get search_api_project_rooms_url(@project.id, q: "market"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ marketing_room.id ], body.map { |room| room["id"] }
  end

  test "ranks closer matches first in fuzzy name search" do
    exact = @project.rooms.create!(type: "Rooms::Open", name: "Design", creator: users(:david))
    partial = @project.rooms.create!(type: "Rooms::Open", name: "Redesign Notes", creator: users(:david))

    get search_api_project_rooms_url(@project.id, q: "design"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    ids = JSON.parse(response.body).map { |room| room["id"] }
    assert_equal [ exact.id, partial.id ], ids
  end

  test "rejects search requests without a token" do
    get search_api_project_rooms_url(@project.id, q: "general")

    assert_response :unauthorized
  end

  test "returns bad request for search without a query param" do
    get search_api_project_rooms_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :bad_request
  end

  test "returns not found for search of an unknown project" do
    get search_api_project_rooms_url("does-not-exist", q: "general"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "creates a room through the api and grants the creating actor membership" do
    post api_rooms_url,
      params: {
        name: "Launch room",
        project_id: @project.id,
        description: "Team room",
        private: true,
        actor_user_id: users(:david).id
      },
      headers: { "Authorization" => "Bearer test-token" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Launch room", body["name"]
    assert_equal true, body["private"]
    assert_equal users(:david).id, body["members"].first["user_id"]
  end

  test "ensures the project room is created idempotently" do
    project = Project.create!(path: "/tmp/api-rooms-ensure-project", name: "Fresh Project")

    post ensure_room_api_project_url(project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    first = JSON.parse(response.body)
    assert_equal true, first["created"]
    assert_equal project.slug, first["name"]

    post ensure_room_api_project_url(project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    second = JSON.parse(response.body)
    assert_equal false, second["created"]
    assert_equal first["id"], second["id"]
  end

  test "updates a room name through the api" do
    patch api_room_url(@room.id),
      params: { name: "Updated room name", description: "Changed" },
      headers: { "Authorization" => "Bearer test-token" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated room name", body["name"]
    assert_equal "Changed", body["description"]
  end
end
