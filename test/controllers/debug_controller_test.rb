require "test_helper"

class DebugControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_admin_debug = ENV["ADMIN_DEBUG"]
    @previous_admin_debug_lower = ENV["admin_debug"]
    ENV["ADMIN_DEBUG"] = "true"
    ENV.delete("admin_debug")
  end

  teardown do
    ENV["ADMIN_DEBUG"] = @previous_admin_debug
    ENV["admin_debug"] = @previous_admin_debug_lower
  end

  test "admin can access debug page when flag is enabled" do
    sign_in :david

    get "/debug"

    assert_response :ok
    assert_select "h1", "Debug"
  end

  test "non-admin cannot access debug page when flag is enabled" do
    sign_in :kevin

    get "/debug"

    assert_response :forbidden
  end

  test "debug page is not found when flag is disabled" do
    sign_in :david

    ENV["ADMIN_DEBUG"] = "false"

    get "/debug"

    assert_response :not_found
  end

  test "debug page renders projects with topic trees and anomalies" do
    sign_in :david

    suffix = "#{Process.pid}-#{rand(1_000_000)}"
    project = Project.create!(path: "/tmp/debug-project-#{suffix}", name: "Debug Alpha")
    other_project = Project.create!(path: "/tmp/debug-project-other-#{suffix}", name: "Debug Beta")

    root_old = Topic.create!(project: project, name: "Root Old", active: true, need_an_action: false, created_at: 3.days.ago)
    root_new = Topic.create!(project: project, name: "Root New", active: true, need_an_action: false, created_at: 2.days.ago)
    Topic.create!(project: project, name: "Child of Root Old", parent_topic: root_old, active: true, need_an_action: false, created_at: 1.day.ago)

    external_parent = Topic.create!(project: other_project, name: "External Parent", active: true, need_an_action: false)
    Topic.create!(project: project, name: "Cross Project Parent", parent_topic_id: external_parent.id, active: true, need_an_action: false)

    cycle_a = Topic.create!(project: project, name: "Cycle A", active: true, need_an_action: false)
    cycle_b = Topic.create!(project: project, name: "Cycle B", active: true, need_an_action: false, parent_topic: cycle_a)
    cycle_a.update!(parent_topic: cycle_b)

    get "/debug"

    assert_response :ok
    assert_includes response.body, "Debug Alpha"
    assert_includes response.body, "Debug Beta"

    assert_includes response.body, "Root Old"
    assert_includes response.body, "Root New"
    assert_includes response.body, "Child of Root Old"
    assert_operator response.body.index("Root Old"), :<, response.body.index("Root New")

    assert_includes response.body, "Cross Project Parent"
    assert_includes response.body, "parent belongs to project id=#{other_project.id}"
    assert_includes response.body, "Cycle A"
    assert_includes response.body, "Cycle B"
    assert_includes response.body, "not reachable from a root topic"
  end

  test "debug page shows project topic, room history, and tool call log tabs" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-tab-project-#{Process.pid}-#{rand(1_000_000)}", name: "Debug Tabs")
    creator = User.find_by(email_address: "david@37signals.com") || User.first
    room = project.rooms.create!(name: "Debug Room", type: "Rooms::Project", private: false, creator: creator)
    topic = Topic.create!(project: project, name: "Topic with history", active: true, need_an_action: false)
    RoomHistoryTopic.create!(room: room, topic: topic, created_date: 1.day.ago, last_state: "active")
    ToolCalLog.create!(project: project, room: room, topic: topic, used_tool_name: "show_debug_tabs", created_date: 2.hours.ago, change_log: "debug tab check")

    get "/debug"

    assert_response :ok
    assert_includes response.body, "Project / Topic"
    assert_includes response.body, "Project / Room / History"
    assert_includes response.body, "Project / Tool Call Log"
    assert_includes response.body, "Topic with history"
    assert_includes response.body, "show_debug_tabs"
    assert_includes response.body, "Debug Room"
  end
end
