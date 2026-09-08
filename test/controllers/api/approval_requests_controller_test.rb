require "test_helper"

class Api::ApprovalRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-approval-requests-test", name: "Api Approval Requests Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    @message = @room.messages.create!(body: "Decision needed", client_message_id: "api-ar-msg-1", creator: users(:david))
    @approval_request = @room.approval_requests.create!(
      message: @message,
      request_type: "decision",
      payload: { "decision" => "Ship it" },
      status: :pending
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all approval requests for a room with a valid token" do
    second_request = @room.approval_requests.create!(
      request_type: "knowledge_proposal",
      payload: { "title" => "Approve playbook" },
      status: :pending
    )

    get api_room_approval_requests_url(@room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ second_request.id, @approval_request.id ], body["approval_requests"].map { |ar| ar["id"] }
  end

  test "returns a single approval request with a valid token" do
    get api_room_approval_request_url(@room.id, @approval_request.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @approval_request.id, body["id"]
    assert_equal "Ship it", body["decision_text"]
  end

  test "allows project-scoped listing with a valid token" do
    get api_project_room_approval_requests_url(@project.id, @room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal @approval_request.id, body["approval_requests"].first["id"]
  end

  test "paginates approval requests when a page param is given" do
    second_request = @room.approval_requests.create!(
      request_type: "knowledge_proposal",
      payload: { "title" => "Approve playbook" },
      status: :pending
    )

    get api_room_approval_requests_url(@room.id, page: 1, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal 1, body["page"]
    assert_equal 1, body["per_page"]
    assert_equal [ second_request.id ], body["approval_requests"].map { |ar| ar["id"] }

    get api_room_approval_requests_url(@room.id, page: 2, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal [ @approval_request.id ], JSON.parse(response.body)["approval_requests"].map { |ar| ar["id"] }
  end

  test "creates an approval request attached to a room and message" do
    assert_difference -> { @room.approval_requests.count }, 1 do
      post api_room_approval_requests_url(@room.id),
        params: { request_type: "decision", message_id: @message.id, payload: { decision: "Launch feature" } },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "decision", body["request_type"]
    assert_equal @message.id, body["message_id"]
    assert_equal "Launch feature", body["decision_text"]
  end

  test "creates an approval request not attached to a message" do
    assert_difference -> { @room.approval_requests.count }, 1 do
      post api_room_approval_requests_url(@room.id),
        params: { request_type: "decision", payload: { decision: "Launch feature" } },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_nil body["message_id"]
    assert_equal "Launch feature", body["decision_text"]
  end

  test "rejects creating an approval request for a message in a different room" do
    other_room = @project.rooms.create!(type: "Rooms::Open", name: "Other", creator: users(:david))
    other_message = other_room.messages.create!(body: "Other", client_message_id: "other-msg", creator: users(:david))

    post api_room_approval_requests_url(@room.id),
      params: { request_type: "decision", message_id: other_message.id, payload: { decision: "No" } },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Message does not belong to the room"
  end

  test "updates an approval request payload" do
    patch api_room_approval_request_url(@room.id, @approval_request.id),
      params: { payload: { decision: "Do not ship" } },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Do not ship", body["decision_text"]
  end

  test "updates status to approved and auto-sets resolved_at" do
    patch api_room_approval_request_url(@room.id, @approval_request.id),
      params: { status: "approved", resolved_by_id: users(:jason).id },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "approved", body["status"]
    assert body["resolved_at"].present?
    assert_equal users(:jason).id, body["resolved_by_id"]
  end

  test "does not override resolved_at when already set" do
    original_resolved_at = 1.day.ago.utc.iso8601(3)
    @approval_request.update!(status: :approved, resolved_at: original_resolved_at)

    patch api_room_approval_request_url(@room.id, @approval_request.id),
      params: { status: "denied" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_in_delta Time.parse(original_resolved_at), @approval_request.reload.resolved_at, 1
  end

  test "deletes an approval request" do
    assert_difference -> { @room.approval_requests.count }, -1 do
      delete api_room_approval_request_url(@room.id, @approval_request.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil ApprovalRequest.find_by(id: @approval_request.id)
  end

  test "returns not found when approval request belongs to a different room" do
    other_room = @project.rooms.create!(type: "Rooms::Open", name: "Other", creator: users(:david))

    get api_room_approval_request_url(other_room.id, @approval_request.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for an unknown room" do
    get api_room_approval_requests_url(-1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "rejects requests without a token" do
    get api_room_approval_requests_url(@room.id)
    assert_response :unauthorized
  end

  test "rejects create requests without a token" do
    post api_room_approval_requests_url(@room.id), params: { request_type: "decision", payload: { decision: "X" } }
    assert_response :unauthorized
  end
end
