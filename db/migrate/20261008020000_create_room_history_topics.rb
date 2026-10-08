class CreateRoomHistoryTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :room_history_topics do |t|
      t.references :room, null: false, foreign_key: true
      t.datetime :created_date, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.text :last_state

      t.timestamps
    end
  end
end
