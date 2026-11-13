require "test_helper"

class ProjectTodoTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", path: "/tmp/test-project-#{SecureRandom.hex(4)}")
  end

  test "validations" do
    todo = @project.todos.build
    assert_not todo.valid?
    assert_includes todo.errors[:title], "can't be blank"

    todo.title = "Finalize Express.js API Routes"
    assert todo.valid?
  end

  test "pending and completed scopes and toggle helper" do
    pending_todo = @project.todos.create!(title: "Pending task", completed: false)
    completed_todo = @project.todos.create!(title: "Done task", completed: true, completed_at: Time.current)

    assert_includes @project.todos.pending, pending_todo
    assert_not_includes @project.todos.pending, completed_todo
    assert_includes @project.todos.completed, completed_todo
    assert_not_includes @project.todos.completed, pending_todo

    pending_todo.toggle_completed!
    assert pending_todo.completed?
    assert pending_todo.completed_at.present?

    pending_todo.toggle_completed!
    assert_not pending_todo.completed?
    assert_nil pending_todo.completed_at
  end

  test "emits completion and reopen events when toggling state" do
    todo = @project.todos.create!(title: "Ship dashboard", completed: false)
    todo.event_actor = users(:david)

    assert_difference -> { OutputEvent.where(event_type: "project_todo_completed").count }, +1 do
      todo.toggle_completed!
    end

    event = OutputEvent.order(:id).last
    assert_equal "project_todo_completed", event.event_type
    assert_equal todo.id, event.event_id
    assert_equal "ProjectTodo", event.event_data["target_type"]
    assert_equal @project.id, event.event_data["project_id"]

    todo.event_actor = users(:david)
    assert_difference -> { OutputEvent.where(event_type: "project_todo_reopened").count }, +1 do
      todo.toggle_completed!
    end
  end
end
