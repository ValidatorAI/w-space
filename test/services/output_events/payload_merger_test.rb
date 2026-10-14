require "test_helper"

class PayloadMergerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "merges sibling events preserving bot_user_ids and content" do
    ev_msg = OutputEvent.create!(
      event_type: "message_created",
      event_id: 50,
      group_id: "grp-50",
      event_data: {
        "content" => "Help with bug",
        "content_payload" => { "room_id" => 12, "message_id" => 50, "text" => "Help with bug" }
      }
    )

    ev_file = OutputEvent.create!(
      event_type: "message_attachment_uploaded",
      event_id: 50,
      group_id: "grp-50",
      event_data: {
        "content_payload" => { "filename" => "log.txt", "content_type" => "text/plain" }
      }
    )

    ev_ai = OutputEvent.create!(
      event_type: "ai_question_asked",
      event_id: 50,
      group_id: "grp-50",
      event_data: {
        "bot_user_ids" => [5, 6],
        "content_payload" => { "bot_user_ids" => [5, 6] }
      }
    )

    merged_type, merged_data = OutputEvents::PayloadMerger.merge([ev_msg, ev_file, ev_ai])

    assert_equal "ai_question_asked", merged_type
    assert_equal "Help with bug", merged_data["content"]
    assert_equal [5, 6], merged_data["bot_user_ids"]
    assert_equal "log.txt", merged_data.dig("content_payload", "filename")
    assert_equal [5, 6], merged_data.dig("content_payload", "bot_user_ids")
  end
end
