require "test_helper"

class OutputEventTest < ActiveSupport::TestCase
  test "requires an event type" do
    event = OutputEvent.new(event_data: {})

    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "requires event data to be a JSON object" do
    event = OutputEvent.new(event_type: "message_created", event_data: [ "invalid" ])

    assert_not event.valid?
    assert_includes event.errors[:event_data], "must be a JSON object"
  end
end