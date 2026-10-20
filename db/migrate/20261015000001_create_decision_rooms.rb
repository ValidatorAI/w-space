class CreateDecisionRooms < ActiveRecord::Migration[7.2]
  def change
    create_table :decision_rooms do |t|
      t.references :room, null: false, foreign_key: true
      t.references :project_adr, null: false, foreign_key: true

      t.timestamps
    end

    add_index :decision_rooms, [ :room_id, :project_adr_id ], unique: true
  end
end
