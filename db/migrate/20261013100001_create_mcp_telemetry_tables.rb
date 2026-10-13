class CreateMcpTelemetryTables < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_call_logs do |t|
      t.string :jsonrpc_id
      t.string :tool_call_name, null: false
      t.json :params_sanitized
      t.boolean :is_error, default: false, null: false
      t.text :error_message
      t.text :result_preview
      t.integer :result_size
      t.integer :duration_ms

      t.timestamps
    end

    add_index :mcp_call_logs, :tool_call_name
    add_index :mcp_call_logs, :is_error
    add_index :mcp_call_logs, :created_at

    create_table :mcp_exceptions do |t|
      t.string :tool_call_name, null: false
      t.string :exception_class, null: false
      t.text :error_message, null: false
      t.text :backtrace
      t.json :params_sanitized

      t.timestamps
    end

    add_index :mcp_exceptions, :tool_call_name
    add_index :mcp_exceptions, :created_at
  end
end
