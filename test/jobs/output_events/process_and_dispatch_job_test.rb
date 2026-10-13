require "test_helper"

class ProcessAndDispatchJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "claims message event and reschedules with settle delay" do
    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 300,
      group_id: "grp-300",
      event_data: { "room_id" => 1, "message_id" => 300, "content" => "Hello" }
    )

    assert_enqueued_with(job: OutputEvents::ProcessAndDispatchJob) do
      OutputEvents::ProcessAndDispatchJob.perform_now(event.id)
    end

    group = OutputEventDispatchGroup.find_by!(dedupe_key: "message:grp-300:1:300")
    assert_equal "deferred_merge_window", group.status
  end

  test "dispatches group and marks member events synced" do
    ev1 = OutputEvent.create!(
      event_type: "message_created",
      event_id: 400,
      group_id: "grp-400",
      event_data: { "room_id" => 1, "message_id" => 400, "content" => "Need advice" }
    )
    ev2 = OutputEvent.create!(
      event_type: "ai_question_asked",
      event_id: 400,
      group_id: "grp-400",
      event_data: { "room_id" => 1, "message_id" => 400, "bot_user_ids" => [9] }
    )

    group = OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-400:1:400",
      lead_output_event_id: ev1.id,
      status: "pending"
    )

    stub_request(:post, "http://127.0.0.1:8642/p/delegator/v1/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "Advice recorded" } }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    OutputEvents::ProcessAndDispatchJob.perform_now(
      ev1.id,
      stage: :dispatch,
      dispatch_group_id: group.id
    )

    assert_equal "dispatched", group.reload.status
    assert group.dispatched_at.present?
    assert ev1.reload.synced?
    assert ev2.reload.synced?

    result = JSON.parse(group.result)
    assert_equal "ai_question_asked", result["event_type"]
    assert_includes result["merged_members"], ev1.id
    assert_includes result["merged_members"], ev2.id
    assert_equal "Advice recorded", Hermes::PromptBuilder.extract_reply_text(result["response"])
  end
end
