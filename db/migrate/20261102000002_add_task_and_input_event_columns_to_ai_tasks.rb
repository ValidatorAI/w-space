class AddTaskAndInputEventColumnsToAiTasks < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:ai_tasks)

    add_column :ai_tasks, :task_id, :integer unless column_exists?(:ai_tasks, :task_id)
    add_column :ai_tasks, :input_event_entity_id, :integer unless column_exists?(:ai_tasks, :input_event_entity_id)

    add_index :ai_tasks, :task_id unless index_exists?(:ai_tasks, :task_id)
    add_index :ai_tasks, :input_event_entity_id unless index_exists?(:ai_tasks, :input_event_entity_id)
  end
end
