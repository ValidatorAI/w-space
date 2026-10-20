class AddProvenanceToRoomEvidences < ActiveRecord::Migration[7.2]
  def change
    add_column :room_evidences, :author_name, :string unless column_exists?(:room_evidences, :author_name)
    add_column :room_evidences, :visibility, :string, default: "project", null: false unless column_exists?(:room_evidences, :visibility)
    add_column :room_evidences, :source_updated_at, :datetime unless column_exists?(:room_evidences, :source_updated_at)

    add_index :room_evidences, :visibility unless index_exists?(:room_evidences, :visibility)
  end
end
