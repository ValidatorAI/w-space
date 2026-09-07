require "test_helper"

class Api::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-messages-test", name: "Api Messages Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    @message = @room.messages.create!(body: "Hello world", client_message_id: "api-msg-1", creator: users(:david))
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns a single message with a valid token" do
    get api_project_room_message_url(@project.id, @room.id, @message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @message.id, body["id"]
    assert_equal "Hello world", body["body"]
  end

  test "rejects requests without a token" do
    get api_project_room_message_url(@project.id, @room.id, @message.id)

    assert_response :unauthorized
  end

  test "returns not found for an unknown message" do
    get api_project_room_message_url(@project.id, @room.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found when message belongs to a different room" do
    other_room = @project.rooms.create!(type: "Rooms::Open", name: "Other", creator: users(:david))

    get api_project_room_message_url(@project.id, other_room.id, @message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns all messages of a room with a valid token" do
    second_message = @room.messages.create!(body: "Second message", client_message_id: "api-msg-2", creator: users(:david))

    get api_project_room_messages_url(@project.id, @room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @message.id, second_message.id ], body["messages"].map { |message| message["id"] }
  end

  test "allows room-scoped message listing without a project_id" do
    second_message = @room.messages.create!(body: "Second message", client_message_id: "api-msg-2", creator: users(:david))

    get api_room_messages_url(@room.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @message.id, second_message.id ], body["messages"].map { |message| message["id"] }
  end

  test "allows posting a message to a room without a project_id" do
    assert_difference -> { @room.messages.count }, 1 do
      post api_room_messages_url(@room.id),
        params: { user_id: users(:jason).id, body: "Posted via room-only API" },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Posted via room-only API", body["body"]
    assert_equal users(:jason).id, body["creator_id"]
  end

  test "paginates messages when a page param is given" do
    second_message = @room.messages.create!(body: "Second message", client_message_id: "api-msg-2", creator: users(:david))

    get api_project_room_messages_url(@project.id, @room.id, page: 1, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal 1, body["page"]
    assert_equal 1, body["per_page"]
    assert_equal [ @message.id ], body["messages"].map { |message| message["id"] }

    get api_project_room_messages_url(@project.id, @room.id, page: 2, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal [ second_message.id ], JSON.parse(response.body)["messages"].map { |message| message["id"] }
  end

  test "rejects index requests without a token" do
    get api_project_room_messages_url(@project.id, @room.id)

    assert_response :unauthorized
  end

  test "returns not found for index of an unknown room" do
    get api_project_room_messages_url(@project.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns the uploaded file for a message with an attachment" do
    message = @room.messages.create_with_attachment! \
      creator: users(:david), client_message_id: "api-msg-attachment",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")

    get attachment_api_project_room_message_url(@project.id, @room.id, message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "rejects attachment requests without a token" do
    message = @room.messages.create_with_attachment! \
      creator: users(:david), client_message_id: "api-msg-attachment-2",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")

    get attachment_api_project_room_message_url(@project.id, @room.id, message.id)

    assert_response :unauthorized
  end

  test "returns not found when message has no attachment" do
    get attachment_api_project_room_message_url(@project.id, @room.id, @message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found for attachment of an unknown message" do
    get attachment_api_project_room_message_url(@project.id, @room.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "posts a message to a room on behalf of a user with a valid token" do
    assert_difference -> { @room.messages.count }, 1 do
      post api_project_room_messages_url(@project.id, @room.id),
        params: { user_id: users(:jason).id, body: "Posted via API" },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Posted via API", body["body"]
    assert_equal users(:jason).id, body["creator_id"]
    assert_equal "User", body["creator_type"]
  end

  test "rejects create requests without a token" do
    post api_project_room_messages_url(@project.id, @room.id), params: { user_id: users(:jason).id, body: "Nope" }

    assert_response :unauthorized
  end

  test "returns bad request when both body and attachment are missing" do
    post api_project_room_messages_url(@project.id, @room.id),
      params: { user_id: users(:jason).id },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :bad_request
  end

  test "posts a file to a room on behalf of a user" do
    assert_difference -> { @room.messages.count }, 1 do
      post api_project_room_messages_url(@project.id, @room.id),
        params: { user_id: users(:jason).id, attachment: fixture_file_upload("moon.jpg", "image/jpeg") },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["has_attachment"]
    assert_equal "moon.jpg", body["attachment_filename"]
    assert_equal "image/jpeg", body["attachment_content_type"]
    assert_not_nil body["attachment_url"]
  end

  test "posts a file with a message body on behalf of a user" do
    post api_project_room_messages_url(@project.id, @room.id),
      params: { user_id: users(:jason).id, body: "Check this out", attachment: fixture_file_upload("moon.jpg", "image/jpeg") },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Check this out", body["body"]
    assert body["has_attachment"]
  end

  test "returns not found when user does not exist" do
    post api_project_room_messages_url(@project.id, @room.id),
      params: { user_id: -1, body: "Posted via API" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "returns not found when posting to an unknown room" do
    post api_project_room_messages_url(@project.id, -1),
      params: { user_id: users(:jason).id, body: "Posted via API" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "updates a message body with a valid token" do
    patch api_project_room_message_url(@project.id, @room.id, @message.id),
      params: { body: "Edited body" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Edited body", body["body"]
    assert_equal "Edited body", @message.reload.plain_text_body
  end

  test "updates a message to add an attachment with a valid token" do
    patch api_project_room_message_url(@project.id, @room.id, @message.id),
      params: { attachment: fixture_file_upload("moon.jpg", "image/jpeg") },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["has_attachment"]
    assert_equal "moon.jpg", body["attachment_filename"]
  end

  test "rejects update requests without a token" do
    patch api_project_room_message_url(@project.id, @room.id, @message.id), params: { body: "Nope" }

    assert_response :unauthorized
  end

  test "returns bad request when update has neither body nor attachment" do
    patch api_project_room_message_url(@project.id, @room.id, @message.id),
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :bad_request
  end

  test "returns not found when updating an unknown message" do
    patch api_project_room_message_url(@project.id, @room.id, -1),
      params: { body: "Edited body" },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "deletes a message with a valid token" do
    assert_difference -> { @room.messages.count }, -1 do
      delete api_project_room_message_url(@project.id, @room.id, @message.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_not Message.exists?(@message.id)
  end

  test "rejects delete requests without a token" do
    delete api_project_room_message_url(@project.id, @room.id, @message.id)

    assert_response :unauthorized
  end

  test "returns not found when deleting an unknown message" do
    delete api_project_room_message_url(@project.id, @room.id, -1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "flat route returns a message by id alone with a valid token" do
    get api_message_url(@message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal @message.id, JSON.parse(response.body)["id"]
  end

  test "flat route rejects requests without a token" do
    get api_message_url(@message.id)

    assert_response :unauthorized
  end

  test "flat route returns not found for an unknown message" do
    get api_message_url(-1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end

  test "flat route updates a message by id alone" do
    patch api_message_url(@message.id), params: { body: "Edited via flat route" }, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal "Edited via flat route", JSON.parse(response.body)["body"]
  end

  test "flat route returns the attachment by id alone" do
    message = @room.messages.create_with_attachment! \
      creator: users(:david), client_message_id: "api-msg-flat-attachment",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")

    get attachment_api_message_url(message.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "flat route deletes a message by id alone" do
    assert_difference -> { Message.count }, -1 do
      delete api_message_url(@message.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
  end
end
