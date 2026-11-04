class RenameTopicToolCallLogsToToolCalLogs < ActiveRecord::Migration[8.0]
  def change
    rename_table :topic_tool_call_logs, :tool_cal_logs

    rename_index :tool_cal_logs,
      :index_topic_tool_call_logs_on_used_tool_name,
      :index_tool_cal_logs_on_used_tool_name

    rename_index :tool_cal_logs,
      :index_topic_tool_call_logs_on_created_date,
      :index_tool_cal_logs_on_created_date

    rename_index :tool_cal_logs,
      :index_topic_tool_call_logs_on_topic_id_and_created_date,
      :index_tool_cal_logs_on_topic_id_and_created_date

    rename_index :tool_cal_logs,
      :index_topic_tool_call_logs_on_room_id_and_created_date,
      :index_tool_cal_logs_on_room_id_and_created_date

    rename_index :tool_cal_logs,
      :index_topic_tool_call_logs_on_project_id_and_created_date,
      :index_tool_cal_logs_on_project_id_and_created_date
  end
end
