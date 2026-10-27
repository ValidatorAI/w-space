require "test_helper"

class Rooms::OpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show redirects to get general show" do
    get rooms_open_url(users(:david).rooms.opens.last)
    assert_redirected_to room_url(users(:david).rooms.opens.last)
  end

  test "new" do
    get new_rooms_open_url
    assert_response :success
  end

  test "new for project only lists project users and labels human vs ai" do
    project = Project.create!(
      name: "Alpha",
      slug: "alpha-#{SecureRandom.hex(4)}",
      path: "/tmp/alpha-#{SecureRandom.hex(8)}"
    )
    ProjectUser.create!(project: project, user: users(:david))
    ProjectUser.create!(project: project, user: users(:bender))
    ProjectUser.create!(project: project, user: users(:kevin))

    get new_rooms_open_url(project_id: project.id)

    assert_response :success
    assert_select "li[data-value='david']", count: 1
    assert_select "li[data-value='kevin']", count: 1
    assert_select "li[data-value='bender bot']", count: 1
    assert_select "li[data-value='jason']", count: 0
    assert_select "li[data-value='david'] span", text: "(Human)", count: 1
    assert_select "li[data-value='bender bot'] span", text: "(AI)", count: 1
  end

  test "create" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      post rooms_opens_url, params: {
        room: {
          name: "My New Room",
          description: "Room for the launch team"
        }
      }
    end

    room = Room.order(:created_at).last
    assert_equal "Room for the launch team", room.description
    assert_equal room.memberships.count, User.count
    assert_redirected_to room_url(room)
  end

  test "create from project settings redirects back to project settings" do
    project = Project.create!(
      name: "Echo",
      slug: "echo-#{SecureRandom.hex(4)}",
      path: "/tmp/echo-#{SecureRandom.hex(8)}"
    )
    ProjectUser.create!(project: project, user: users(:david))

    post rooms_opens_url, params: {
      from_project_settings: "1",
      room: {
        name: "Project Settings Room",
        project_id: project.id
      }
    }

    assert_redirected_to edit_rooms_project_url(project.id, by: "project")
  end

  test "create forbidden by non-admin when account restricts creation to admins" do
    accounts(:signal).settings.restrict_room_creation_to_administrators = true
    accounts(:signal).save!

    sign_in :jz
    post rooms_opens_url, params: { room: { name: "My New Room" } }
    assert_response :forbidden
  end

  test "only admins or creators can update" do
    sign_in :jz

    assert_turbo_stream_broadcasts :rooms, count: 0 do
      put rooms_open_url(rooms(:hq)), params: { room: { name: "New Name" } }
    end

    assert_response :forbidden
    assert rooms(:hq).reload.name, "HQ"
  end

  test "update" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      put rooms_open_url(rooms(:pets)), params: { room: { name: "New Name" } }
    end

    assert_redirected_to room_url(rooms(:pets))
    assert rooms(:pets).reload.name, "New Name"
  end

  test "update a closed room to be open" do
    put rooms_open_url(rooms(:designers)), params: { room: { name: "Doesn't matter" } }
    assert_equal rooms(:designers).memberships.count, User.count
  end

  test "update a project closed room to open only grants project users" do
    project = Project.create!(
      name: "Delta",
      slug: "delta-#{SecureRandom.hex(4)}",
      path: "/tmp/delta-#{SecureRandom.hex(8)}"
    )
    ProjectUser.create!(project: project, user: users(:david))
    ProjectUser.create!(project: project, user: users(:kevin))

    room = Rooms::Closed.create!(name: "Private Project Room", creator: users(:david), project: project)
    room.memberships.grant_to(users(:david))

    put rooms_open_url(room), params: { room: { name: room.name } }

    room = Room.find(room.id)
    assert_includes room.users, users(:david)
    assert_includes room.users, users(:kevin)
    assert_not_includes room.users, users(:jason)
  end
end
