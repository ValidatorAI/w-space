class CreateAiProfileSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_profile_skills do |t|
      t.references :ai_profile, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :ai_profile_skills, [ :ai_profile_id, :skill_id ], unique: true
  end
end
