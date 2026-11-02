class AddTaskContextColumnsToAiTasks < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:ai_tasks)

    add_column :ai_tasks, :proposed_task_context, :string unless column_exists?(:ai_tasks, :proposed_task_context)
    add_column :ai_tasks, :actual_task_context, :string unless column_exists?(:ai_tasks, :actual_task_context)
  end
end
