require "test_helper"

class Api::TopicRelatedEntitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"

    @project = Project.create!(
      path: "/tmp/api-topic-entities-#{SecureRandom.hex(4)}",
      name: "Topic API Project"
    )

    @room = @project.rooms.create!(
      type: "Rooms::Project",
      name: "Topic Room",
      creator: users(:david)
    )

    @message = @room.messages.create!(
      body: "Test message",
      creator: users(:david)
    )

    @topic = @project.topics.create!(
      name: "Alpha Topic",
      active: true,
      need_an_action: false,
      importance_level: 3
    )

    @message_topic = MessageTopic.create!(topic: @topic, message: @message, created_date: Time.current)
    @room_history_topic = RoomHistoryTopic.create!(room: @room, last_state: "open", created_date: Time.current)
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "topics can be filtered by project_id and room_id" do
    get api_topics_url, params: { project_id: @project.id, active: true }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body["topics"].map { |row| row["id"] }, @topic.id

    get api_topics_url, params: { room_id: @room.id }, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body["topics"].map { |row| row["id"] }, @topic.id
  end

  test "room history topics can be filtered by room_id" do
    get api_room_history_topics_url, params: { room_id: @room.id }, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body["room_history_topics"].map { |row| row["id"] }, @room_history_topic.id
  end

  test "message analysis resources support CRUD" do
    post api_message_analysis_index_url,
      params: {
        message_id: @message.id,
        importance_level: 4,
        message_content_summary: "Summary",
        message_type: "text",
        tags: "tag-one,tag-two",
        is_a_response: false
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    analysis = JSON.parse(response.body)
    assert_equal @message.id, analysis["message_id"]

    get api_message_analysis_url(analysis["id"]), headers: { "Authorization" => "Bearer test-token" }
    assert_response :success

    patch api_message_analysis_url(analysis["id"]),
      params: { importance_level: 5 },
      headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    assert_equal 5, JSON.parse(response.body)["importance_level"]

    delete api_message_analysis_url(analysis["id"]), headers: { "Authorization" => "Bearer test-token" }
    assert_response :no_content
  end
end
