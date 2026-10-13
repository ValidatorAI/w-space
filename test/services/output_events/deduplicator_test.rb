require "test_helper"

class DeduplicatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "generates message family dedupe key when group_id and message info are present" do
    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 123,
      group_id: "group-uuid-1",
      event_data: {
        "room_id" => 45,
        "content_payload" => { "message_id" => 123, "room_id" => 45 }
      }
    )

    key = OutputEvents::Deduplicator.dedupe_key_for(event)
    assert_equal "message:group-uuid-1:45:123", key
    assert OutputEvents::Deduplicator.key_needs_settle?(key)
  end

  test "generates event family dedupe key for non-message events" do
    event = OutputEvent.create!(
      event_type: "account_updated",
      event_id: 99,
      event_data: { "name" => "Acme Corp" }
    )

    key = OutputEvents::Deduplicator.dedupe_key_for(event)
    assert_match(/\Aevent:account_updated:99:[0-9a-f]{16}\z/, key)
    assert_not OutputEvents::Deduplicator.key_needs_settle?(key)
  end

  test "claims new key and detects subsequent duplicates" do
    event1 = OutputEvent.create!(
      event_type: "message_created",
      event_id: 200,
      group_id: "grp-100",
      event_data: { "room_id" => 10, "message_id" => 200 }
    )
    event2 = OutputEvent.create!(
      event_type: "ai_question_asked",
      event_id: 200,
      group_id: "grp-100",
      event_data: { "room_id" => 10, "message_id" => 200, "bot_user_ids" => [1, 2] }
    )

    claim1 = OutputEvents::Deduplicator.claim(event1)
    assert claim1.claimed?
    assert_not claim1.duplicate?
    assert_equal "message:grp-100:10:200", claim1.dedupe_key
    assert_equal "pending", claim1.group.status

    claim2 = OutputEvents::Deduplicator.claim(event2)
    assert claim2.duplicate?
    assert_not claim2.claimed?
    assert_equal claim1.group.id, claim2.group.id
  end
end
