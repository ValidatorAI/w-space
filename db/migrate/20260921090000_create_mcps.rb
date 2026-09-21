class CreateMcps < ActiveRecord::Migration[8.0]
  def change
    create_table :mcps do |t|
      t.string :name, null: false
      t.string :transport, null: false
      t.string :url, null: false
      t.string :authentication, null: false
      t.string :bearer_token
      t.string :status, null: false

      t.timestamps
    end

    add_index :mcps, :name
  end
end