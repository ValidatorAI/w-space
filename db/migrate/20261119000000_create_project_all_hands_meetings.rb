class CreateProjectAllHandsMeetings < ActiveRecord::Migration[8.0]
  def change
    create_table :project_all_hands_meetings, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :bbb_meeting_id, null: false
      t.string :moderator_pw, null: false
      t.string :attendee_pw, null: false
      t.string :join_url
      t.boolean :running, default: false, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :last_seen_at
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :project_all_hands_meetings, :project_id, if_not_exists: true
    add_index :project_all_hands_meetings, :bbb_meeting_id, unique: true, if_not_exists: true
    add_index :project_all_hands_meetings, :position, if_not_exists: true
  end
end
