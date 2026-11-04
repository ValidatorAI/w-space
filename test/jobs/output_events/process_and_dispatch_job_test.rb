require "test_helper"

class ProcessAndDispatchJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  setup do
    ENV["OUTPUT_MESSAGE_PROFILE"] = "message_analyzer"
    ENV["OUTPUT_AI_SETTING_PROFILE"] = "ai_settings"

    stub_request(:get, "http://127.0.0.1:9119/api/status")
      .to_return(
        status: 200,
        body: { "gateway_busy" => false, "active_agents" => 0, "active_sessions" => 0, "overall" => "healthy" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

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

    stub_request(:post, "http://127.0.0.1:8642/p/message_analyzer/v1/chat/completions")
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

  test "routes AI setting events to the AI settings profile and message events to the message profile" do
    ai_event = OutputEvent.create!(
      event_type: "ai_setting_created",
      event_id: 500,
      group_id: "grp-500",
      event_data: { "label" => "max_workers", "setting_value" => 3 }
    )

    message_event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 501,
      group_id: "grp-501",
      event_data: { "room_id" => 1, "message_id" => 501, "content" => "Hello" }
    )

    ai_group = OutputEventDispatchGroup.create!(
      dedupe_key: "ai_setting:grp-500",
      lead_output_event_id: ai_event.id,
      status: "pending"
    )

    message_group = OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-501:1:501",
      lead_output_event_id: message_event.id,
      status: "pending"
    )

    stub_request(:post, "http://127.0.0.1:8642/p/ai_settings/v1/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "config ok" } }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "http://127.0.0.1:8642/p/message_analyzer/v1/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "message ok" } }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    OutputEvents::ProcessAndDispatchJob.perform_now(
      ai_event.id,
      stage: :dispatch,
      dispatch_group_id: ai_group.id
    )

    OutputEvents::ProcessAndDispatchJob.perform_now(
      message_event.id,
      stage: :dispatch,
      dispatch_group_id: message_group.id
    )

    ai_result = JSON.parse(ai_group.reload.result)
    message_result = JSON.parse(message_group.reload.result)

    assert_equal "ai_settings", ai_result["profile"]
    assert_equal "message_analyzer", message_result["profile"]
  end

  test "uses OUTPUT_MESSAGE_PROFILE for room and message family events when configured" do
    previous_message_profile = ENV["OUTPUT_MESSAGE_PROFILE"]
    previous_ai_setting_profile = ENV["OUTPUT_AI_SETTING_PROFILE"]
    ENV["OUTPUT_MESSAGE_PROFILE"] = "message_analyzer"
    ENV["OUTPUT_AI_SETTING_PROFILE"] = "ai_settings"

    job = OutputEvents::ProcessAndDispatchJob.new

    assert_equal "message_analyzer", job.send(:resolve_profile, "message_created", { "room_id" => 1 })
    assert_equal "message_analyzer", job.send(:resolve_profile, "approval_request_approved", { "room_id" => 1 })
    assert_equal "message_analyzer", job.send(:resolve_profile, "decision_approved", { "room_id" => 1 })

    ENV["OUTPUT_MESSAGE_PROFILE"] = previous_message_profile
    ENV["OUTPUT_AI_SETTING_PROFILE"] = previous_ai_setting_profile
  end

  test "uses OUTPUT_WORKSPACE_PROFILE for project and task workspace events when configured" do
    previous_message_profile = ENV["OUTPUT_MESSAGE_PROFILE"]
    previous_workspace_profile = ENV["OUTPUT_WORKSPACE_PROFILE"]
    ENV["OUTPUT_MESSAGE_PROFILE"] = "message_analyzer"
    ENV["OUTPUT_WORKSPACE_PROFILE"] = "workspace"

    job = OutputEvents::ProcessAndDispatchJob.new

    assert_equal "workspace", job.send(:resolve_profile, "project_created", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "project_updated", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "all_hands_action_item_completed", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "all_hands_action_item_reopened", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "project_todo_completed", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "project_todo_reopened", { "project_id" => 10 })
    assert_equal "workspace", job.send(:resolve_profile, "decision_waiting_resolved", { "target_type" => "AttentionItem" })
    assert_equal "workspace", job.send(:resolve_profile, "risk_approved", { "target_type" => "CompanyStatusItem" })

    ENV["OUTPUT_MESSAGE_PROFILE"] = previous_message_profile
    ENV["OUTPUT_WORKSPACE_PROFILE"] = previous_workspace_profile
  end

  test "throttles dispatch when Hermes active agents exceed threshold" do
    stub_request(:get, "http://127.0.0.1:9119/api/status")
      .to_return(
        status: 200,
        body: { "gateway_busy" => true, "active_agents" => 2, "active_sessions" => 5, "overall" => "busy" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    ev = OutputEvent.create!(
      event_type: "message_created",
      event_id: 450,
      group_id: "grp-450",
      event_data: { "room_id" => 1, "message_id" => 450 }
    )

    group = OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-450:1:450",
      lead_output_event_id: ev.id,
      status: "pending"
    )

    assert_enqueued_with(job: OutputEvents::ProcessAndDispatchJob, args: [ev.id, { stage: :dispatch, dispatch_group_id: group.id }]) do
      OutputEvents::ProcessAndDispatchJob.perform_now(
        ev.id,
        stage: :dispatch,
        dispatch_group_id: group.id
      )
    end

    assert_equal "pending", group.reload.status
  end
end
