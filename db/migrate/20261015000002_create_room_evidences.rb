class CreateRoomEvidences < ActiveRecord::Migration[7.2]
  def change
    create_table :room_evidences do |t|
      t.references :room, null: false, foreign_key: true
      t.references :project_external_asset, foreign_key: true
      t.references :project_knowledge_item, foreign_key: true
      t.string :evidence_type, null: false
      t.string :title
      t.string :summary
      t.string :source_label
      t.string :owner_name
      t.text :provenance
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :room_evidences, [ :room_id, :project_external_asset_id ], unique: true,
      where: "project_external_asset_id IS NOT NULL"
    add_index :room_evidences, [ :room_id, :project_knowledge_item_id ], unique: true,
      where: "project_knowledge_item_id IS NOT NULL"
  end
end
