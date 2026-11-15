require "test_helper"

class AiTaskDispatchPollJobTest < ActiveSupport::TestCase
  test "dispatches the earliest undispatched task to its assignee profile" do
    first_task = AiTask.create!(description: "First task", assigneee_profile: "coder", dispatched: false)
    later_task = AiTask.create!(description: "Second task", assigneee_profile: "delegator", dispatched: false)

    hermes_client = mock
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{first_task.id}" }] },
      profile: "coder",
      timeout: Hermes.configuration.dispatch_timeout
    ).returns({ "choices" => [{ "message" => { "content" => "received" } }] })

    Hermes::Client.expects(:new).returns(hermes_client)

    AiTaskDispatchPollJob.perform_now

    assert_equal true, first_task.reload.dispatched
    assert_equal false, later_task.reload.dispatched
    assert_equal "coder", first_task.assigneee_profile
  end

  test "skips blank assignee rows before dispatching the next valid task" do
    blank_task = AiTask.create!(description: "Blank assignee task", assigneee_profile: "   ", dispatched: false)
    valid_task = AiTask.create!(description: "Valid task", assigneee_profile: "coder", dispatched: false)

    hermes_client = mock
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{valid_task.id}" }] },
      profile: "coder",
      timeout: Hermes.configuration.dispatch_timeout
    ).returns({ "choices" => [{ "message" => { "content" => "received" } }] })

    Hermes::Client.expects(:new).returns(hermes_client)

    AiTaskDispatchPollJob.perform_now

    assert_equal false, blank_task.reload.dispatched
    assert_equal true, valid_task.reload.dispatched
    assert_equal "coder", valid_task.assigneee_profile
  end

  test "dispatches with the configured Hermes dispatch timeout" do
    task = AiTask.create!(description: "Timeout task", assigneee_profile: "coder", dispatched: false)
    Hermes.configure do |config|
      config.dispatch_timeout = 42.0
    end

    hermes_client = mock
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{task.id}" }] },
      profile: "coder",
      timeout: 42.0
    ).returns({ "choices" => [{ "message" => { "content" => "received" } }] })

    Hermes::Client.expects(:new).returns(hermes_client)

    AiTaskDispatchPollJob.perform_now

    assert_equal true, task.reload.dispatched
  end

  test "a failed head task stops poisoning the queue after three consecutive dispatch failures" do
    project = Project.create!(name: "Dispatch project", path: "/tmp/dispatch-project-#{SecureRandom.hex(4)}", slug: "dispatch-project-#{SecureRandom.hex(4)}")
    bad_task = AiTask.create!(project: project, description: "Bad task", assigneee_profile: "planner", dispatched: false)
    good_task = AiTask.create!(project: project, description: "Good task", assigneee_profile: "coder", dispatched: false)

    hermes_client = mock
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{bad_task.id}" }] },
      profile: "planner",
      timeout: Hermes.configuration.dispatch_timeout
    ).raises(Hermes::Client::HttpError.new("profile not found", status_code: 404, response_body: "{}"))
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{bad_task.id}" }] },
      profile: "planner",
      timeout: Hermes.configuration.dispatch_timeout
    ).raises(Hermes::Client::HttpError.new("profile not found", status_code: 404, response_body: "{}"))
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{bad_task.id}" }] },
      profile: "planner",
      timeout: Hermes.configuration.dispatch_timeout
    ).raises(Hermes::Client::HttpError.new("profile not found", status_code: 404, response_body: "{}"))
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{good_task.id}" }] },
      profile: "coder",
      timeout: Hermes.configuration.dispatch_timeout
    ).returns({ "choices" => [{ "message" => { "content" => "received" } }] })

    Hermes::Client.expects(:new).returns(hermes_client).at_least_once

    4.times { AiTaskDispatchPollJob.perform_now }

    bad_task.reload
    good_task.reload

    assert_equal 3, bad_task.dispatch_attempts
    assert_match(/profile not found|profile.*not.*exist/i, bad_task.dispatch_error.to_s)
    assert_equal false, bad_task.finished
    assert_equal true, bad_task.dispatched
    assert_equal 1, AttentionItem.where(project_id: project.id, category: "blockers", status: "pending").count
    assert_equal true, good_task.dispatched
    assert_equal "coder", good_task.assigneee_profile
  end

  test "dispatch failure blockers prefer the task room over the project" do
    project = Project.create!(name: "Room project", path: "/tmp/room-project-#{SecureRandom.hex(4)}", slug: "room-project-#{SecureRandom.hex(4)}")
    room = project.rooms.create!(name: "Ops room", type: "Rooms::Open", private: false, creator: User.create!(name: "ops", display_name: "Ops", email_address: "ops-#{SecureRandom.hex(4)}@example.com", role: :member))
    task = AiTask.create!(project: project, room: room, description: "Room-scoped failure", assigneee_profile: "planner", dispatched: false)

    task.send(:create_dispatch_failure_blocker!, "profile not found")

    blocker = AttentionItem.order(:id).last
    assert_equal room.id, blocker.room_id
    assert_equal project.id, blocker.project_id
  end
end
