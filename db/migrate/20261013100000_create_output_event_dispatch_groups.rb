class CreateOutputEventDispatchGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :output_event_dispatch_groups do |t|
      t.string :dedupe_key, null: false
      t.bigint :lead_output_event_id
      t.string :status, null: false, default: "pending"
      t.datetime :dispatched_at
      t.text :result

      t.timestamps
    end

    add_index :output_event_dispatch_groups, :dedupe_key, unique: true
    add_index :output_event_dispatch_groups, :status
    add_index :output_event_dispatch_groups, :lead_output_event_id
  end
end
