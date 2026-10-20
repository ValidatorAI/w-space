class CreateMessageTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :message_topics do |t|
      t.references :topic, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.datetime :created_date, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end
  end
end
