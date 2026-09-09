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
      assert_equal({ "type" => "User", "id" => actor.id }, event.event_data["actor"])
      assert_equal(
        "<knowledge_path>\n- /company/#{Account.first.id}/projects/#{project.id}/knowledge\n</knowledge_path>",
        event.event_data["knowledge_path"]
      )
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
end