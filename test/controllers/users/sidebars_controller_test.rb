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
    child_room.memberships.grant_to(users(:david))

    get user_sidebar_url

    assert_operator @response.body.index(parent_room.name), :<, @response.body.index(child_room.name)
    assert_select "#room_#{child_room.id}_list.room-item--child"
  end

  test "rooms without parent or project are not shown in shared rooms" do
    orphan_room = Rooms::Open.create!(name: "No Parent No Project", creator: users(:jason))
    orphan_room.memberships.grant_to(users(:david))

    get user_sidebar_url

    assert_no_match(/#{Regexp.escape(orphan_room.name)}/, @response.body)
  end

  test "project knowledge section uses the same indented sidebar pattern as other project nav links" do
    project = Project.create!(
      name: "Knowledge Pad",
      path: "/tmp/knowledge-pad-#{SecureRandom.hex(4)}"
    )
    project.project_users.create!(user: users(:david))

    project_room = project.ensure_project_room!
    project_room.memberships.grant_to(users(:david))

    get user_sidebar_url

    assert_response :success
    assert_select ".sidebar-projects__knowledge--offset", count: 1
    assert_select %(a[aria-label="#{project.display_name} Knowledge"]), count: 1
  end

  test "project sidebar rows expose project id hooks for active item centering" do
    project = Project.create!(
      name: "Project Scroll Target",
      path: "/tmp/project-scroll-target-#{SecureRandom.hex(4)}"
    )
    project.project_users.create!(user: users(:david))
    project.ensure_project_room!

    get user_sidebar_url

    assert_response :success
    assert_select ".sidebar-projects__item[data-project-id='#{project.id}']", count: 1
  end

  test "archived project keeps settings row but hides sub-items" do
    project = Project.create!(
      name: "Archive Visibility",
      path: "/tmp/archive-visibility-#{SecureRandom.hex(4)}"
    )
    project.project_users.create!(user: users(:david))

    project_room = project.ensure_project_room!
    project_room.memberships.grant_to(users(:david))

    room_name = "room-hidden-#{SecureRandom.hex(4)}"
    channel = Rooms::Open.create!(
      name: room_name,
      creator: users(:david),
      project: project,
      parent: project_room
    )
    channel.memberships.grant_to(users(:david))

    project_room.archive!

    get user_sidebar_url

    assert_response :success
    assert_match project.display_name, @response.body
    assert_select %(a[aria-label="#{project.display_name} settings"]), count: 1
    assert_select %(a[aria-label="Create room in #{project.display_name}"]), count: 0
    assert_select %(a[aria-label="#{project.display_name} Overview"]), count: 0
    assert_select %(a[aria-label="#{project.display_name} Status"]), count: 0
    assert_select %(a[aria-label="#{project.display_name} All-Hands"]), count: 0
    assert_select %(a[aria-label="#{project.display_name} Knowledge"]), count: 0
    assert_no_match channel.name, @response.body
  end
end
