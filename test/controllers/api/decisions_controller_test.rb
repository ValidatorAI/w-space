require "test_helper"

class Api::DecisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-decisions-test", name: "Api Decisions Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    @approval_request = ApprovalRequest.create!(
      room: @room,
      request_type: "decision",
      payload: { "decision" => "Ship it" },
      status: :pending
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "approves a decision on behalf of a user" do
    post api_project_room_decisions_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "approve" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "approved", body["status"]
    assert_equal users(:jason).id, @approval_request.reload.resolved_by_id
  end

  test "denies a decision on behalf of a user with a note" do
    post api_project_room_decisions_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "deny", note: "Not ready" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal "denied", JSON.parse(response.body)["status"]
    assert_equal "Not ready", @approval_request.reload.approval_request_actions.last.note
  end

  test "rejects requests without a token" do
    post api_project_room_decisions_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "approve" }

    assert_response :unauthorized
  end

  test "returns bad request for an unsupported decision" do
    post api_project_room_decisions_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "explode" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :bad_request
  end

  test "returns not found when user does not exist" do
    post api_project_room_decisions_url(@project.id, @room.id),
      params: { user_id: -1, approval_request_id: @approval_request.id, decision: "approve" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found when approval request does not belong to the room" do
    other_room = @project.rooms.create!(type: "Rooms::Open", name: "Other", creator: users(:david))

    post api_project_room_decisions_url(@project.id, other_room.id),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "approve" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for an unknown room" do
    post api_project_room_decisions_url(@project.id, -1),
      params: { user_id: users(:jason).id, approval_request_id: @approval_request.id, decision: "approve" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end
end
