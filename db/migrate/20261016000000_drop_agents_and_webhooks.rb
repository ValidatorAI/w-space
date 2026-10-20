class DropAgentsAndWebhooks < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :file_reservations, :agents if foreign_key_exists?(:file_reservations, :agents)
    remove_foreign_key :approval_requests, :agents if foreign_key_exists?(:approval_requests, :agents)
    remove_foreign_key :room_ai_activity_states, :agents if foreign_key_exists?(:room_ai_activity_states, :agents)

    remove_column :file_reservations, :agent_id, if_exists: true
    remove_column :approval_requests, :agent_id, if_exists: true
    remove_column :room_ai_activity_states, :agent_id, if_exists: true

    drop_table :agents, if_exists: true
    drop_table :webhooks, if_exists: true
  end

  def down
    create_table :agents do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :program, null: false
      t.string :model, null: false
      t.text :task_description
      t.integer :status, default: 0, null: false
      t.string :api_token
      t.datetime :last_active_at
      t.timestamps
    end

    add_index :agents, [:project_id, :name], unique: true
    add_index :agents, :api_token, unique: true
    add_index :agents, :status

    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.timestamps
    end
  end
end
