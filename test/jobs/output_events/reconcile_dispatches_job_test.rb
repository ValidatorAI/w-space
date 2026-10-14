require "test_helper"

class ReconcileDispatchesJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  setup do
    @hermes_status = {
      "gateway_busy" => false,
      "active_agents" => 1,
      "active_sessions" => 3,
      "overall" => "healthy"
    }

    stub_request(:get, "http://127.0.0.1:9119/api/status")
      .to_return(status: 200, body: @hermes_status.to_json, headers: { "Content-Type" => "application/json" })
  end

  test "re-enqueues stale pending groups within lookback window" do
    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 501,
      group_id: "grp-stale-1",
      event_data: { "room_id" => 1, "message_id" => 501 }
    )

    group = OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-stale-1:1:501",
      lead_output_event_id: event.id,
      status: "deferred_merge_window",
      created_at: 2.minutes.ago
    )

    assert_enqueued_with(job: OutputEvents::ProcessAndDispatchJob, args: [event.id, { stage: :dispatch, dispatch_group_id: group.id }]) do
      result = OutputEvents::ReconcileDispatchesJob.perform_now
      assert_equal 1, result[:reconciled_count]
      assert_includes result[:reconciled_group_ids], group.id
    end
  end

  test "expires groups older than lookback window" do
    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 502,
      group_id: "grp-expired-1",
      event_data: { "room_id" => 1, "message_id" => 502 }
    )

    group = OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-expired-1:1:502",
      lead_output_event_id: event.id,
      status: "pending",
      created_at: 20.minutes.ago
    )

    result = OutputEvents::ReconcileDispatchesJob.perform_now(max_age: 15.minutes)
    assert_equal 1, result[:expired_count]
    assert_equal "failed", group.reload.status
    assert_includes group.result, "Reconciliation expired"
  end

  test "throttles when active_agents exceeds threshold" do
    stub_request(:get, "http://127.0.0.1:9119/api/status")
      .to_return(
        status: 200,
        body: { "gateway_busy" => true, "active_agents" => 3, "active_sessions" => 5, "overall" => "busy" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    event = OutputEvent.create!(
      event_type: "message_created",
      event_id: 503,
      group_id: "grp-throttle-1",
      event_data: { "room_id" => 1, "message_id" => 503 }
    )

    OutputEventDispatchGroup.create!(
      dedupe_key: "message:grp-throttle-1:1:503",
      lead_output_event_id: event.id,
      status: "pending",
      created_at: 2.minutes.ago
    )

    assert_no_enqueued_jobs do
      result = OutputEvents::ReconcileDispatchesJob.perform_now
      assert_equal true, result[:throttled]
      assert_equal 0, result[:reconciled_count]
    end
  end
end
