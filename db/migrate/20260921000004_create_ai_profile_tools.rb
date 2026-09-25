class CreateAiProfileTools < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_profile_tools do |t|
      t.references :ai_profile, null: false, foreign_key: true
      t.references :tool, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :ai_profile_tools, [ :ai_profile_id, :tool_id ], unique: true
  end
end
