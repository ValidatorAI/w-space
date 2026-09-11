require "test_helper"

class OutputEvents::RecorderTest < ActiveSupport::TestCase
  test "persists an unsynced event with knowledge_path and enqueues delivery" do
    actor = users(:david)
    group_id = SecureRandom.uuid
    project = Project.create!(name: "Output Event Project", path: "/tmp/output-events-#{SecureRandom.hex(6)}")

    assert_enqueued_with(job: OutputEvents::DeliverJob) do
      event = OutputEvents::Recorder.record(
        event_type: "project_updated",
        event_id: project.id,
        group_id: group_id,
        actor: actor,
        target_type: "Project",
        data: {}
      )

      assert_not event.synced?
      assert_equal project.id, event.event_id
      assert_equal group_id, event.group_id
      assert_equal "Project", event.event_data["target_type"]
      assert_equal(
        { "type" => "User", "id" => actor.id, "username" => actor.name, "full_name" => actor.effective_display_name },
        event.event_data["actor"]
      )
      assert_equal(
        "<knowledge_path>\n- /company/#{Account.first.id}/projects/#{project.id}/knowledge\n</knowledge_path>",
        event.event_data["knowledge_path"]
      )
      assert event.event_data.key?("content")
      assert event.event_data.key?("content_payload")
      assert_nil event.event_data["content"]
      assert_nil event.event_data["content_payload"]
    end
  end

  test "omits knowledge_path when no project context can be inferred" do
    actor = users(:david)

    event = OutputEvents::Recorder.record(
      event_type: "user_banned",
      event_id: actor.id,
      actor: actor,
      target_type: "User",
      data: {}
    )

    assert_nil event.event_data["knowledge_path"]
  end

  test "does not persist filtered typing action events" do
    actor = users(:david)

    assert_no_difference -> { OutputEvent.count } do
      assert_no_enqueued_jobs only: OutputEvents::DeliverJob do
        result = OutputEvents::Recorder.record(
          event_type: "typing_start",
          event_id: 1,
          actor: actor,
          target_type: "Room",
          data: { "room_id" => rooms(:watercooler).id }
        )

        assert_nil result
      end
    end
  end

  test "extracts message content and structured payload" do
    room = rooms(:watercooler)
    message = room.messages.create_with_attachment!(body: "Ship the change", creator: users(:david))

    event = OutputEvents::Recorder.record(
      event_type: "message_created",
      event_id: message.id,
      actor: message.creator,
      target_type: "Message",
      data: { "room_id" => room.id, "content_type" => "text" }
    )

    assert_equal "Ship the change", event.event_data["content"]
    assert_equal "message", event.event_data.dig("content_payload", "type")
    assert_equal message.id, event.event_data.dig("content_payload", "message_id")
    assert_equal room.id, event.event_data.dig("content_payload", "room_id")
  end

  test "extracts approval decision content" do
    room = rooms(:watercooler)
    request = ApprovalRequest.create!(
      room: room,
      request_type: "decision",
      payload: { "decision" => "Use the batched delivery path" }
    )

    event = OutputEvents::Recorder.record(
      event_type: "decision_approved",
      event_id: request.id,
      actor: users(:david),
      target_type: "ApprovalRequest",
      data: {
        "request_type" => request.request_type,
        "room_id" => room.id,
        "status" => "approved",
        "approval_request_action" => "approve"
      }
    )

    assert_equal "Use the batched delivery path", event.event_data["content"]
    assert_equal "decision", event.event_data.dig("content_payload", "type")
    assert_equal request.id, event.event_data.dig("content_payload", "approval_request_id")
  end

  test "extracts attention item resolution content" do
    attention_item = AttentionItem.create!(
      title: "Approve legal terms",
      category: "decisions_waiting",
      status: :resolved
    )

    event = OutputEvents::Recorder.record(
      event_type: "decision_waiting_resolved",
      event_id: attention_item.id,
      actor: users(:david),
      target_type: "AttentionItem",
      data: {
        "category" => attention_item.category,
        "status" => attention_item.status,
        "action_label" => "Approve"
      }
    )

    assert_equal "Approve legal terms", event.event_data["content"]
    assert_equal "attention_item_resolution", event.event_data.dig("content_payload", "type")
    assert_equal attention_item.id, event.event_data.dig("content_payload", "attention_item_id")
    assert_equal "decisions_waiting", event.event_data.dig("content_payload", "category")
    assert_equal "resolved", event.event_data.dig("content_payload", "status")
  end
end