require "test_helper"

class Users::SidebarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get user_sidebar_url

    users(:david).rooms.opens.each do |room|
      assert_match /#{room.name}/, @response.body
    end
  end

  test "contact picker lists active humans and workspace bots except the current user" do
    deactivated_user = User.create!(name: "Former User", display_name: "Former User", status: :deactivated)

    get user_sidebar_url

    assert_response :success
    assert_select "dialog.direct-contacts" do
      assert_select "#direct-contacts-humans", text: "Humans"
      assert_select "#direct-contacts-bots", text: "Bots"
      assert_select "form[action='#{rooms_directs_path(user_ids: [ users(:jason).id ])}']", count: 1
      assert_select "form[action='#{rooms_directs_path(user_ids: [ users(:bender).id ])}']", count: 1
      assert_select "[data-direct-contacts-modal-search-value='david']", count: 0
      assert_select "[data-direct-contacts-modal-search-value='#{deactivated_user.effective_display_name.downcase}']", count: 0
    end
  end

  test "unread directs" do
    rooms(:david_and_jason).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.select { |m| m.room.direct? && m.unread? }.count
  end


  test "unread other" do
    rooms(:watercooler).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.reject { |m| m.room.direct? || !m.unread? }.count
  end

  test "child rooms are listed under their parent" do
    parent_room = rooms(:pets)
    child_room = Rooms::Open.create!(name: "Thread A", creator: users(:david), parent: parent_room)
    Membership.create!(room: child_room, participant: users(:david), involvement: "mentions")

    get user_sidebar_url

    assert_operator @response.body.index(parent_room.name), :<, @response.body.index(child_room.name)
    assert_select "#room_#{child_room.id}_list.room-item--child"
  end

  test "rooms without parent or project are not shown in shared rooms" do
    orphan_room = Rooms::Open.create!(name: "No Parent No Project", creator: users(:jason))
    Membership.create!(room: orphan_room, participant: users(:david), involvement: "mentions")

    get user_sidebar_url

    assert_no_match(/#{Regexp.escape(orphan_room.name)}/, @response.body)
  end
end
