require "test_helper"

class AiTaskDispatchPollJobTest < ActiveSupport::TestCase
  test "dispatches the earliest undispatched task to its assignee profile" do
    first_task = AiTask.create!(description: "First task", assigneee_profile: "coder", dispatched: false)
    later_task = AiTask.create!(description: "Second task", assigneee_profile: "delegator", dispatched: false)

    hermes_client = mock
    hermes_client.expects(:chat_completions).with(
      { messages: [{ role: "user", content: "you have new task with id #{first_task.id}" }] },
      profile: "coder"
    ).returns({ "choices" => [{ "message" => { "content" => "received" } }] })

    Hermes::Client.expects(:new).returns(hermes_client)

    AiTaskDispatchPollJob.perform_now

    assert_equal true, first_task.reload.dispatched
    assert_equal false, later_task.reload.dispatched
    assert_equal "coder", first_task.assigneee_profile
  end
end
