require "test_helper"

class Api::ActionsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-actions-test", name: "Api Actions Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "broadcasts a typing_start action on behalf of a user" do
    assert_broadcasts(TypingNotificationsChannel.broadcasting_for(@room), 1) do
      post api_project_room_actions_url(@project.id, @room.id),
        params: { user_id: users(:jason).id, action_type: "typing_start" },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :accepted
    assert_equal "typing_start", JSON.parse(response.body)["action"]
  end

  test "broadcasts a typing_stop action on behalf of a user" do
    assert_broadcasts(TypingNotificationsChannel.broadcasting_for(@room), 1) do
      post api_project_room_actions_url(@project.id, @room.id),
        params: { user_id: users(:jason).id, action_type: "typing_stop" },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :accepted
  end

  test "typing actions do not create output events" do
    assert_no_difference -> { OutputEvent.count } do
      post api_project_room_actions_url(@project.id, @room.id),
        params: { user_id: users(:jason).id, action_type: "typing_start" },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :accepted
  end

  test "rejects requests without a token" do
    post api_project_room_actions_url(@project.id, @room.id), params: { user_id: users(:jason).id, action_type: "typing_start" }

    assert_response :unauthorized
  end

  test "returns bad request for an unsupported action" do
    post api_project_room_actions_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, action_type: "explode" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :bad_request
  end

  test "returns not found when user does not exist" do
    post api_project_room_actions_url(@project.id, @room.id),
      params: { user_id: -1, action_type: "typing_start" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for an unknown room" do
    post api_project_room_actions_url(@project.id, -1),
      params: { user_id: users(:jason).id, action_type: "typing_start" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for an unknown project" do
    post api_project_room_actions_url("does-not-exist", @room.id),
      params: { user_id: users(:jason).id, action_type: "typing_start" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end
end
