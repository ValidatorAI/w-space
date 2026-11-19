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

  test "room history tab groups projects and rooms and keeps history in ascending date order" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-room-history-project-#{Process.pid}-#{rand(1_000_000)}", name: "Room History Project")
    creator = User.find_by(email_address: "david@37signals.com") || User.first
    room_alpha = project.rooms.create!(name: "Room Alpha", type: "Rooms::Open", private: false, creator: creator)
    room_beta = project.rooms.create!(name: "Room Beta", type: "Rooms::Open", private: false, creator: creator)

    topic_a = Topic.create!(project: project, name: "Alpha Topic", active: true, need_an_action: false)
    topic_b = Topic.create!(project: project, name: "Beta Topic", active: true, need_an_action: false)

    old_alpha = RoomHistoryTopic.create!(room: room_alpha, topic: topic_a, created_date: 4.days.ago, last_state: "older alpha")
    new_alpha = RoomHistoryTopic.create!(room: room_alpha, topic: topic_a, created_date: 1.day.ago, last_state: "newer alpha")
    middle_beta = RoomHistoryTopic.create!(room: room_beta, topic: topic_b, created_date: 2.days.ago, last_state: "beta history")

    get "/debug"

    assert_response :ok
    assert_operator response.body.index("Room Alpha"), :<, response.body.index("Room Beta")
    assert_operator response.body.index(old_alpha.last_state), :<, response.body.index(new_alpha.last_state)
    assert_operator response.body.index("older alpha"), :<, response.body.index("newer alpha")
    assert_operator response.body.index("older alpha"), :<, response.body.index("beta history")
  end

  test "tool call log tab groups project, room, and topic logs in hierarchy order" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-tool-hierarchy-#{Process.pid}-#{rand(1_000_000)}", name: "Tool Hierarchy Project")
    creator = User.find_by(email_address: "david@37signals.com") || User.first
    room = project.rooms.create!(name: "Tool Room", type: "Rooms::Open", private: false, creator: creator)
    topic = Topic.create!(project: project, name: "Tool Topic", active: true, need_an_action: false)

    ToolCalLog.create!(project: project, used_tool_name: "project_scope_sync", created_date: 2.hours.ago, change_log: "project level log")
    ToolCalLog.create!(project: project, room: room, used_tool_name: "room_scope_sync", created_date: 1.hour.ago, change_log: "room level log")
    ToolCalLog.create!(project: project, room: room, topic: topic, used_tool_name: "topic_scope_sync", created_date: 30.minutes.ago, change_log: "topic level log")

    get "/debug"

    assert_response :ok
    assert_includes response.body, "Project logs"
    assert_includes response.body, "Room logs"
    assert_includes response.body, "Topic logs"
    assert_includes response.body, "project_scope_sync"
    assert_includes response.body, "room_scope_sync"
    assert_includes response.body, "topic_scope_sync"
    assert_operator response.body.index("Project logs"), :<, response.body.index("Room logs")
    assert_operator response.body.index("Room logs"), :<, response.body.index("Topic logs")
    assert_select "details.debug-tool-log-section--project", 1
    assert_select "details.debug-tool-log-section--room", 1
    assert_select "details.debug-tool-log-section--topic", 1
    assert_select "details.debug-tool-log-group--room", 1
    assert_select "details.debug-tool-log-group--topic", 1
  end

  test "debug topic page is available when admin debug is enabled" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-topic-page-#{Process.pid}-#{rand(1_000_000)}", name: "Topic Page Project")
    topic = Topic.create!(
      project: project,
      name: "Topic Page Topic",
      active: true,
      need_an_action: true,
      importance_level: 3,
      state: "ready",
      memory: "important context",
      related_topics: "peer topic",
      required_actions: "review"
    )

    get "/debug/topic/#{topic.id}"

    assert_response :ok
    assert_includes response.body, "Topic Page Topic"
    assert_includes response.body, "Topic debug"
    assert_includes response.body, "Need an action"
    assert_includes response.body, "Importance level"
    assert_includes response.body, "State"
    assert_includes response.body, "Memory"
    assert_includes response.body, "important context"
  end

  test "debug topic page shows related messages ordered by date" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-topic-messages-#{Process.pid}-#{rand(1_000_000)}", name: "Topic Messages Project")
    creator = User.find_by(email_address: "david@37signals.com") || User.first
    room = project.rooms.create!(name: "Topic Messages Room", type: "Rooms::Open", private: false, creator: creator)
    topic = Topic.create!(project: project, name: "Message Topic", active: true, need_an_action: false)

    older_message = room.messages.create!(body: "older message", creator: creator, created_at: 3.days.ago)
    newer_message = room.messages.create!(body: "newer message", creator: creator, created_at: 1.day.ago)

    MessageTopic.create!(topic: topic, message: older_message, created_date: older_message.created_at)
    MessageTopic.create!(topic: topic, message: newer_message, created_date: newer_message.created_at)

    get "/debug/topic/#{topic.id}"

    assert_response :ok
    assert_includes response.body, "Topic messages"
    assert_includes response.body, "older message"
    assert_includes response.body, "newer message"
    assert_operator response.body.index("older message"), :<, response.body.index("newer message")
  end

  test "debug message page shows related topics for the message" do
    sign_in :david

    project = Project.create!(path: "/tmp/debug-message-topics-#{Process.pid}-#{rand(1_000_000)}", name: "Message Topics Project")
    creator = User.find_by(email_address: "david@37signals.com") || User.first
    room = project.rooms.create!(name: "Message Topics Room", type: "Rooms::Open", private: false, creator: creator)
    first_topic = Topic.create!(project: project, name: "First Topic", active: true, need_an_action: false)
    second_topic = Topic.create!(project: project, name: "Second Topic", active: true, need_an_action: false)
    message = room.messages.create!(body: "debug message body", creator: creator, created_at: 2.days.ago)

    MessageTopic.create!(topic: second_topic, message: message, created_date: 1.day.ago)
    MessageTopic.create!(topic: first_topic, message: message, created_date: 2.days.ago)

    get "/debug/message/#{message.id}"

    assert_response :ok
    assert_includes response.body, "Message debug"
    assert_includes response.body, "debug message body"
    assert_includes response.body, "First Topic"
    assert_includes response.body, "Second Topic"
    assert_operator response.body.index("First Topic"), :<, response.body.index("Second Topic")
  end
end
