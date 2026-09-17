require "test_helper"

class OutputEvents::DeliverJobTest < ActiveJob::TestCase
  setup do
    @previous_url = ENV["OUTPUT_EVENTS_URL"]
    ENV["OUTPUT_EVENTS_URL"] = "https://events.example.test/output-events"
  end

  teardown do
    ENV["OUTPUT_EVENTS_URL"] = @previous_url
  end

  test "posts an unsynced event and marks it synced after a successful response" do
    group_id = SecureRandom.uuid
    knowledge_path = "<knowledge_path>\n- /company/1/projects/2/knowledge\n</knowledge_path>"
    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 42,
      group_id: group_id,
      event_data: {
        "actor" => {
          "type" => "User",
          "id" => users(:david).id,
          "username" => users(:david).name,
          "full_name" => users(:david).effective_display_name
        },
        "target_type" => "Message",
        "knowledge_path" => knowledge_path
      }
    )
    stub_request(:post, ENV.fetch("OUTPUT_EVENTS_URL")).to_return(status: 201)

    OutputEvents::DeliverJob.perform_now(event.id)

    assert event.reload.synced?
    assert_requested :post, ENV.fetch("OUTPUT_EVENTS_URL"), body: hash_including(
      "id" => event.id,
      "event_type" => "message_created",
      "event_id" => 42,
      "group_id" => group_id,
      "event_data" => hash_including(
        "actor" => hash_including(
          "username" => users(:david).name,
          "full_name" => users(:david).effective_display_name
        ),
        "knowledge_path" => knowledge_path
      )
    )
  end

  test "skips an event that was already synced" do
    event = OutputEvent.create!(event_type: "message_created", event_data: {}, synced: true)

    OutputEvents::DeliverJob.perform_now(event.id)

    assert_not_requested :post, ENV.fetch("OUTPUT_EVENTS_URL")
  end

  test "posts attachment events as multipart with full file" do
    message = rooms(:watercooler).messages.create_with_attachment!(
      body: "Attached file",
      creator: users(:david),
      attachment: Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/moon.jpg"), "image/jpeg")
    )
    event = OutputEvent.create!(
      event_type: "message_attachment_uploaded",
      event_id: message.id,
      event_data: { "room_id" => message.room_id }
    )

    stub_request(:post, ENV.fetch("OUTPUT_EVENTS_URL")).with { |request|
      content_type = request.headers["Content-Type"].to_s
      content_type.include?("multipart/form-data") &&
        request.body.include?("name=\"event\"") &&
        request.body.include?("\"event_type\":\"message_attachment_uploaded\"") &&
        request.body.include?("name=\"file\"; filename=\"moon.jpg\"")
    }.to_return(status: 201)

    OutputEvents::DeliverJob.perform_now(event.id)

    assert event.reload.synced?
    assert_requested :post, ENV.fetch("OUTPUT_EVENTS_URL")
  end
end