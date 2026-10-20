class CreateDecisionRoomEconomics < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:decision_room_economics)
      create_table :decision_room_economics do |t|
        t.references :decision_room, null: false, foreign_key: true
        t.integer :research_effort
        t.integer :guided_build_effort
        t.integer :expected_learning_value
        t.string :risk_level
        t.text :risk_note
        t.text :summary

        t.timestamps
      end
    end

    unless index_exists?(:decision_room_economics, :decision_room_id)
      add_index :decision_room_economics, :decision_room_id, unique: true
    end
  end
end
