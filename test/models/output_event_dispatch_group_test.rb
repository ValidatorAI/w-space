require "test_helper"

class OutputEventDispatchGroupTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @event = OutputEvent.create!(
      event_type: "message_created",
      event_data: { "text" => "hello" }
    )
  end

  test "validates presence of dedupe_key" do
    group = OutputEventDispatchGroup.new(status: "pending")
    assert_not group.valid?
    assert_includes group.errors[:dedupe_key], "can't be blank"
  end

  test "validates uniqueness of dedupe_key" do
    OutputEventDispatchGroup.create!(dedupe_key: "msg:1:2:3", status: "pending")
    duplicate = OutputEventDispatchGroup.new(dedupe_key: "msg:1:2:3", status: "pending")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:dedupe_key], "has already been taken"
  end

  test "validates status inclusion" do
    group = OutputEventDispatchGroup.new(dedupe_key: "unique:1", status: "invalid_status")
    assert_not group.valid?
    assert_includes group.errors[:status], "is not included in the list"

    %w[pending dispatched duplicate_merged failed deferred_merge_window].each do |valid_status|
      group.status = valid_status
      assert group.valid?, "Expected #{valid_status} to be valid"
    end
  end

  test "associations and scopes" do
    g1 = OutputEventDispatchGroup.create!(
      dedupe_key: "key:1",
      status: "pending",
      lead_output_event: @event
    )
    g2 = OutputEventDispatchGroup.create!(
      dedupe_key: "key:2",
      status: "dispatched",
      lead_output_event: @event
    )
    g3 = OutputEventDispatchGroup.create!(
      dedupe_key: "key:3",
      status: "failed"
    )

    assert_equal @event, g1.lead_output_event
    assert_includes @event.output_event_dispatch_groups, g1
    assert_includes @event.output_event_dispatch_groups, g2

    assert_includes OutputEventDispatchGroup.pending, g1
    assert_not_includes OutputEventDispatchGroup.pending, g2

    assert_includes OutputEventDispatchGroup.dispatched, g2
    assert_includes OutputEventDispatchGroup.failed, g3
  end
end
