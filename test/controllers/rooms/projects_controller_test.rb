require "test_helper"

class Rooms::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david

    @project = Project.create!(
      name: "Alpha",
      slug: "alpha-#{SecureRandom.hex(4)}",
      path: "/tmp/alpha-#{SecureRandom.hex(8)}"
    )
    ProjectUser.create!(project: @project, user: users(:david))

    @project_room = @project.ensure_project_room!
    @project_room.memberships.grant_to(users(:david))

    @channel = Rooms::Open.create!(
      name: "general",
      creator: users(:david),
      project: @project,
      parent: @project_room
    )
    @channel.memberships.grant_to(users(:david))

  end

  test "edit renders project settings sections" do
    get edit_rooms_project_url(@project.id, by: "project")

    assert_response :success
    assert_match "Project Details", @response.body
    assert_match "Teammates", @response.body
    assert_match "Channel Management", @response.body
    assert_match "Danger Zone", @response.body
  end

  test "edit shows only attached bots in attached AI teammates" do
    attached_bot = User.create_bot!(name: "Attached Bot", display_name: "Attached Bot")
    @project_room.memberships.grant_to(attached_bot)

    detached_bot = User.create_bot!(name: "Detached Bot", display_name: "Detached Bot")

    get edit_rooms_project_url(@project.id, by: "project")

    assert_response :success
    assert_match "Attached Bot", @response.body
    assert_no_match "Detached Bot", @response.body
  end

  test "update project details syncs project room" do
    patch rooms_project_url(@project_room.id), params: {
      project: {
        name: "Renamed Alpha",
        description: "New description",
        private: "1"
      }
    }

    assert_redirected_to edit_rooms_project_url(@project.id, by: "project")
    assert_equal "Renamed Alpha", @project.reload.name
    assert_equal "New description", @project.description
    assert_equal true, @project.private?

    assert_equal "Renamed Alpha", @project_room.reload.name
    assert_equal "New description", @project_room.description
    assert_equal true, @project_room.private?
  end

  test "archive channel archives selected project channel" do
    patch rooms_project_url(@project_room.id), params: {
      intent: "archive_channel",
      channel_id: @channel.id
    }

    assert_redirected_to edit_rooms_project_url(@project.id, by: "project")
    assert @channel.reload.archived?
  end

  test "unarchive channel restores selected project channel" do
    @channel.archive!

    patch rooms_project_url(@project_room.id), params: {
      intent: "unarchive_channel",
      channel_id: @channel.id
    }

    assert_redirected_to edit_rooms_project_url(@project.id, by: "project")
    assert_not @channel.reload.archived?
  end

  test "channel management lists top-level channels including archived" do
    nested_channel = Rooms::Open.create!(
      name: "nested",
      creator: users(:david),
      project: @project,
      parent: @channel
    )
    nested_channel.memberships.grant_to(users(:david))

    archived_channel = Rooms::Open.create!(
      name: "archived-top-level",
      creator: users(:david),
      project: @project,
      parent: @project_room,
      archived_at: Time.current
    )
    archived_channel.memberships.grant_to(users(:david))

    get edit_rooms_project_url(@project.id, by: "project")

    assert_response :success
    assert_match "general", @response.body
    assert_match "archived-top-level", @response.body
    assert_no_match "nested", @response.body
  end

  test "archive project archives all active project rooms" do
    patch rooms_project_url(@project_room.id), params: { intent: "archive_project" }

    assert_redirected_to root_url
    assert @project_room.reload.archived?
    assert @channel.reload.archived?
  end

  test "delete project removes project and rooms" do
    assert_difference -> { Project.count }, -1 do
      patch rooms_project_url(@project_room.id), params: { intent: "delete_project" }
    end

    assert_redirected_to root_url
    assert_not Room.exists?(@project_room.id)
    assert_not Room.exists?(@channel.id)
  end

  test "non-admin cannot update" do
    sign_in :jz
    @project_room.memberships.grant_to(users(:jz))
    ProjectUser.create!(project: @project, user: users(:jz))

    patch rooms_project_url(@project_room.id), params: {
      project: { name: "Blocked rename" }
    }

    assert_response :forbidden
    assert_not_equal "Blocked rename", @project.reload.name
  end
end
