class CreateAiProfileMcps < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_profile_mcps do |t|
      t.references :ai_profile, null: false, foreign_key: true
      t.references :mcp, null: false, foreign_key: { to_table: :mcps }
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :ai_profile_mcps, [ :ai_profile_id, :mcp_id ], unique: true
  end
end