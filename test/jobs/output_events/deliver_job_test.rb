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
      "event_data" => hash_including("knowledge_path" => knowledge_path)
    )
  end

  test "skips an event that was already synced" do
    event = OutputEvent.create!(event_type: "message_created", event_data: {}, synced: true)

    OutputEvents::DeliverJob.perform_now(event.id)

    assert_not_requested :post, ENV.fetch("OUTPUT_EVENTS_URL")
  end
end