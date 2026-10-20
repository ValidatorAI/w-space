class AddUsdUsedToTasks < ActiveRecord::Migration[7.2]
  def change
    add_column :tasks, :usd_used, :float
  end
end
