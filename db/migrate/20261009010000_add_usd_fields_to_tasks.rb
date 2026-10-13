class AddUsdFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :usd_usage, :float
    add_column :tasks, :usd_budget, :float
  end
end
