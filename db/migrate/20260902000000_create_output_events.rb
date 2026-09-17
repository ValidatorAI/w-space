class CreateOutputEvents < ActiveRecord::Migration[8.2]
  def change
    create_table :output_events do |t|
      t.string :event_type, null: false
      t.integer :event_id
      t.json :event_data, null: false, default: {}
      t.boolean :synced, null: false, default: false

      t.timestamps
    end

    add_index :output_events, :event_type
    add_index :output_events, :event_id
    add_index :output_events, [ :synced, :created_at ]
  end
end