class AddTopicIdToRoomHistoryTopics < ActiveRecord::Migration[8.0]
  def change
    add_reference :room_history_topics, :topic, foreign_key: true, null: true
    add_index :room_history_topics, [:room_id, :topic_id], name: "index_room_history_topics_on_room_id_and_topic_id"
  end
end
