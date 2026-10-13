class AddGrandParentIdToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :grand_parent_id, :integer
    add_index :tasks, :grand_parent_id
  end
end
