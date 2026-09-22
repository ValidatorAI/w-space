class AddStdioFieldsToMcps < ActiveRecord::Migration[8.2]
  def change
    add_column :mcps, :command, :string
    add_column :mcps, :args, :text
    add_column :mcps, :environment, :text
  end
end
