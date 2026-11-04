require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "creates a task with expected defaults and project linkage" do
    project = Project.create!(name: "Test Project", path: "/tmp/test-project-#{SecureRandom.hex(4)}")

    parent_task = project.tasks.create!(description: "Parent task", importance: 1, level: 1)
    topic = project.topics.create!(name: "Write API topic", active: true, need_an_action: false)

    task = project.tasks.create!(
      description: "Write API",
      importance: 3,
      level: 1,
      usd_budget: 99.99,
      parent_task_id: parent_task.id,
      grand_parent_id: parent_task.id,
      topic: topic
    )

    assert_equal project.id, task.project_id
    assert_equal false, task.dispatched
    assert_equal false, task.finished
    assert_equal topic.id, task.topic_id
    assert_equal topic, task.topic
    assert_equal parent_task.id, task.parent_task_id
    assert_equal parent_task.id, task.grand_parent_id
    assert_equal "Write API", task.description
    assert_equal 99.99, task.usd_budget
  end
end
