class AddDispatchTrackingToAiTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_tasks, :dispatch_attempts, :integer, default: 0, null: false
    add_column :ai_tasks, :dispatch_error, :text
  end
end
