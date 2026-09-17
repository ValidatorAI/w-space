class CleanupProjectAllHandsMeetingState < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:project_all_hands_meetings)
      drop_table :project_all_hands_meetings, if_exists: true
    end

    %i[
      project_all_hands_takeaways
      project_all_hands_action_items
      project_all_hands_decisions
    ].each do |table_name|
      if foreign_key_exists?(table_name, :project_all_hands_meetings)
        remove_foreign_key table_name, :project_all_hands_meetings
      end

      if column_exists?(table_name, :project_all_hands_meeting_id)
        remove_column table_name, :project_all_hands_meeting_id
      end
    end
  end

  def down
    create_table :project_all_hands_meetings, if_not_exists: true do |t|
      t.integer :project_id, null: false
      t.string :title, null: false
      t.datetime :held_at
      t.integer :duration_minutes, default: 45
      t.string :leader_name
      t.text :notes
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :project_all_hands_meetings, :project_id unless index_exists?(:project_all_hands_meetings, :project_id)
    add_index :project_all_hands_meetings, :position unless index_exists?(:project_all_hands_meetings, :position)
    add_foreign_key :project_all_hands_meetings, :projects unless foreign_key_exists?(:project_all_hands_meetings, :projects)

    %i[project_all_hands_takeaways project_all_hands_action_items project_all_hands_decisions].each do |table_name|
      unless column_exists?(table_name, :project_all_hands_meeting_id)
        add_column table_name, :project_all_hands_meeting_id, :integer
      end
      unless index_exists?(table_name, :project_all_hands_meeting_id)
        add_index table_name, :project_all_hands_meeting_id
      end
      add_foreign_key table_name, :project_all_hands_meetings unless foreign_key_exists?(table_name, :project_all_hands_meetings)
    end
  end
end
