require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "index redirects to the user's last room" do
    get rooms_url
    assert_redirected_to room_url(users(:david).rooms.last)
  end

  test "show" do
    get room_url(users(:david).rooms.last)
    assert_response :success
  end

  test "shows records the last room visited in a cookie" do
    get room_url(users(:david).rooms.last)
    assert response.cookies[:last_room] = users(:david).rooms.last.id
  end

  test "destroy" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      assert_difference -> { Room.count }, -1 do
        delete room_url(rooms(:designers))
      end
    end
  end

  test "show interleaves parent and child room messages chronologically" do
    parent_room = rooms(:designers)
    first_child_room = Rooms::Open.create_for({ name: "UI Refactor", creator: users(:david), parent: parent_room }, users: [ users(:david) ])
    second_child_room = Rooms::Open.create_for({ name: "Accessibility", creator: users(:david), parent: parent_room }, users: [ users(:david) ])

    first_child_room.messages.create!(body: "First child message", creator: users(:david), created_at: 3.minutes.ago)
    parent_room.messages.create!(body: "Parent message", creator: users(:david), created_at: 2.minutes.ago)
    second_child_room.messages.create!(body: "Second child message", creator: users(:david), created_at: 1.minute.ago)

    get room_url(parent_room)
    assert_response :success
    assert_operator response.body.index("First child message"), :<, response.body.index("Parent message")
    assert_operator response.body.index("Parent message"), :<, response.body.index("Second child message")
    assert_select ".message__topic", text: "Topic: UI Refactor"
    assert_select ".message__topic", text: "Topic: Accessibility"
    assert_select ".message__topic", count: 2
  end

  test "destroy only allowed for creators or those who can administer" do
    sign_in :jz

    assert_no_difference -> { Room.count } do
      delete room_url(rooms(:designers))
      assert_response :forbidden
    end

    rooms(:designers).update! creator: users(:jz)

    assert_difference -> { Room.count }, -1 do
      delete room_url(rooms(:designers))
    end
  end
end
