require "test_helper"

class Api::OutputEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-output-events", name: "Output Events Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    @message = @room.messages.create!(body: "Alpha message", creator: users(:david), client_message_id: "evt-msg-1")
    @event = OutputEvent.create!(event_type: "message_created", event_data: {
      "room_id" => @room.id,
      "content_payload" => { "message_id" => @message.id },
      "message_text" => "Alpha message"
    })
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "lists output events with filters and payload" do
    get "/api/output_events?event_type=message_created&synced=false&limit=50",
        headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal "message_created", body["output_events"].first["event_type"]
    assert_equal "Alpha message", body["output_events"].first["event_data"]["message_text"]
  end

  test "requeues an output event through the Hermes dispatch pipeline" do
    assert_enqueued_with(job: OutputEvents::ProcessAndDispatchJob, args: [@event.id]) do
      post redeliver_api_output_event_url(@event.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @event.id, body["id"]
    assert_equal "message_created", body["event_type"]
    assert_equal true, body["requeued"]
    assert_equal false, body["synced"]
  end
end
