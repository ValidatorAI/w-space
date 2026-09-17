require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper, ActiveJob::TestHelper

  test "creating a message enqueues to push later" do
    assert_enqueued_jobs 1, only: [ Room::PushMessageJob ] do
      create_new_message_in rooms(:designers)
    end
  end

  test "all emoji" do
    assert Message.new(body: "😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "Haha! 😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥\nmultiple lines\n💯").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥 💯").plain_text_body.all_emoji?
  end

  test "mentionees" do
    message = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_with_duplicate_mentions = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)} #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_mentioning_a_non_member = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:kevin)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [], message_mentioning_a_non_member.mentionees
  end

  test "is invalid when body is blank and no attachment exists" do
    message = Message.new(room: rooms(:pets), creator: users(:jason), client_message_id: "earth", body: "")

    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "creating a message in child room broadcasts to parent room stream" do
    parent_room = rooms(:designers)
    child_room = Rooms::Open.create_for({ name: "Child Topic", creator: users(:david), parent: parent_room }, users: [ users(:david) ])

    assert_turbo_stream_broadcasts [ parent_room, :messages ], count: 1 do
      message = child_room.messages.create!(creator: users(:david), body: "Syncing to parent", client_message_id: "test-sync")
      message.broadcast_create
    end
  end

  private
    def create_new_message_in(room)
      room.messages.create!(creator: users(:jason), body: "Hello", client_message_id: "123")
    end
end
