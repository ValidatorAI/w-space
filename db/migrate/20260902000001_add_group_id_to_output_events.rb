class AddGroupIdToOutputEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :output_events, :group_id, :string
    add_index :output_events, :group_id
  end
end