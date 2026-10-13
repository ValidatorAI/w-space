require "test_helper"

class McpExceptionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "validates required fields" do
    exc = McpException.new
    assert_not exc.valid?
    assert_includes exc.errors[:tool_call_name], "can't be blank"
    assert_includes exc.errors[:exception_class], "can't be blank"
    assert_includes exc.errors[:error_message], "can't be blank"
  end

  test "creates successfully and scopes by recent" do
    e1 = McpException.create!(
      tool_call_name: "add_message",
      exception_class: "ActiveRecord::RecordNotFound",
      error_message: "Room not found",
      backtrace: "app/models/room.rb:10"
    )
    e2 = McpException.create!(
      tool_call_name: "edit_project_todo",
      exception_class: "StandardError",
      error_message: "Crash",
      backtrace: "app/models/project_todo.rb:15"
    )

    assert_equal [e2, e1], McpException.where(id: [e1.id, e2.id]).recent.to_a
  end
end
