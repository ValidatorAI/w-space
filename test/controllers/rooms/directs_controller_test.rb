require "test_helper"

class Rooms::DirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "create" do
    post rooms_directs_url, params: { user_ids: [ users(:jz).id ] }

    room = Room.last
    assert_redirected_to room_url(room)
    assert room.users.include?(users(:david))
    assert room.users.include?(users(:jz))
  end

  test "create only once per user set" do
    assert_difference -> { Room.all.count }, +1 do
      post rooms_directs_url, params: { user_ids: [ users(:jz).id ] }
      post rooms_directs_url, params: { user_ids: [ users(:jz).id ] }
    end
  end

  test "create a direct room with a workspace bot only once" do
    assert_difference -> { Rooms::Direct.count }, +1 do
      2.times { post rooms_directs_url, params: { user_ids: [ users(:bender).id ] } }
    end

    room = Rooms::Direct.order(:created_at).last
    assert_equal [ users(:david).id, users(:bender).id ].sort, room.user_ids.sort
    assert_redirected_to room_url(room)
  end

  test "create with initial message" do
    assert_difference -> { Rooms::Direct.count }, +1 do
      assert_difference -> { Message.count }, +1 do
        post rooms_directs_url, params: { user_ids: [ users(:bender).id ], message: { body: "What changed this week?" } }
      end
    end

    room = Rooms::Direct.order(:created_at).last
    message = room.messages.last
    assert_redirected_to room_url(room)
    assert_equal "What changed this week?", message.plain_text_body
    assert_equal users(:david), message.creator
    assert_equal [ users(:david).id, users(:bender).id ].sort, room.user_ids.sort
  end

  test "create with initial message reuses existing direct room" do
    post rooms_directs_url, params: { user_ids: [ users(:bender).id ] }
    room = Rooms::Direct.order(:created_at).last

    assert_no_difference -> { Rooms::Direct.count } do
      assert_difference -> { Message.count }, +1 do
        post rooms_directs_url, params: { user_ids: [ users(:bender).id ], message: { body: "Summarize the company status" } }
      end
    end

    assert_redirected_to room_url(room)
    assert_equal "Summarize the company status", room.messages.last.plain_text_body
  end

  test "create with initial message in human direct does not record message output events" do
    assert_no_difference -> { OutputEvent.where(event_type: "message_created").count } do
      assert_no_difference -> { OutputEvent.where(event_type: "ai_question_asked").count } do
        post rooms_directs_url, params: { user_ids: [ users(:jz).id ], message: { body: "Private sync" } }
      end
    end

    assert_redirected_to room_url(Rooms::Direct.order(:created_at).last)
  end

  test "create with initial message in user-bot direct records message output events" do
    assert_difference -> { OutputEvent.where(event_type: "message_created").count }, +1 do
      assert_difference -> { OutputEvent.where(event_type: "ai_question_asked").count }, +1 do
        post rooms_directs_url, params: { user_ids: [ users(:bender).id ], message: { body: "Need bot summary" } }
      end
    end

    assert_redirected_to room_url(Rooms::Direct.order(:created_at).last)
  end

  test "destroy only allowed for all room users" do
    sign_in :kevin

    assert_difference -> { Room.count }, -1 do
      delete rooms_direct_url(rooms(:david_and_kevin))
      assert_redirected_to root_url
    end
  end
end
