require "test_helper"

class MessageCreationEventsTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess
  test "records the full message trio for a human message in a bot direct room" do
    room = rooms(:bender_and_kevin)
    message = room.messages.create_with_attachment!(
      body: "Need help",
      creator: users(:kevin),
      client_message_id: "svc-trio",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")
    )

    MessageCreationEvents.record(message: message, room: room, mode: "ask")

    assert_equal %w[ai_question_asked message_attachment_uploaded message_created].sort,
      OutputEvent.where(event_id: message.id).pluck(:event_type).uniq.sort

    group_ids = OutputEvent.where(event_id: message.id).pluck(:group_id).compact
    assert_equal 1, group_ids.uniq.count

    ai_event = OutputEvent.find_by!(event_type: "ai_question_asked", event_id: message.id)
    assert_equal [users(:bender).id], ai_event.event_data["bot_user_ids"]
    assert_equal "ask", ai_event.event_data["mode"]

    attachment_event = OutputEvent.find_by!(event_type: "message_attachment_uploaded", event_id: message.id)
    assert_equal "moon.jpg", attachment_event.event_data["filename"]
  end

  test "ignores bot-authored messages" do
    room = rooms(:bender_and_kevin)
    message = room.messages.create!(
      body: "I am a bot",
      creator: users(:bender),
      client_message_id: "svc-bot"
    )

    assert_no_difference -> { OutputEvent.count } do
      MessageCreationEvents.record(message: message, room: room, mode: "message")
    end
  end
end
