class RemoveUsdUsageFromAiTasks < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:ai_tasks)

    remove_column :ai_tasks, :usd_usage, :float if column_exists?(:ai_tasks, :usd_usage)
  end
end
