class AddTopicIdToAiTasks < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:ai_tasks)

    add_column :ai_tasks, :topic_id, :integer unless column_exists?(:ai_tasks, :topic_id)
    add_index :ai_tasks, :topic_id unless index_exists?(:ai_tasks, :topic_id)
  end
end
