class CreateTopicToolCallLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :topic_tool_call_logs do |t|
      t.references :topic, foreign_key: true, null: true
      t.references :room, foreign_key: true, null: true
      t.references :project, foreign_key: true, null: true

      t.datetime :created_date, null: false
      t.string :used_tool_name, null: false
      t.string :target_entity_id
      t.text :change_log
      t.text :why_was_it_required

      t.timestamps
    end

    add_index :topic_tool_call_logs, :used_tool_name
    add_index :topic_tool_call_logs, :created_date
    add_index :topic_tool_call_logs, [:topic_id, :created_date]
    add_index :topic_tool_call_logs, [:room_id, :created_date]
    add_index :topic_tool_call_logs, [:project_id, :created_date]
  end
end
