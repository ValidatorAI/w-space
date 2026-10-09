require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "creates a task with expected defaults and project linkage" do
    project = Project.create!(name: "Test Project", path: "/tmp/test-project-#{SecureRandom.hex(4)}")

    task = project.tasks.create!(description: "Write API", importance: 3, level: 1)

    assert_equal project.id, task.project_id
    assert_equal false, task.added_to_kanban
    assert_equal false, task.runned
    assert_nil task.parent_task_id
    assert_equal "Write API", task.description
  end
end
