class CreateAiProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_profiles do |t|
      t.string :profile_name, null: false
      t.text :soul
      t.boolean :bot, default: false, null: false
      t.string :bot_name
      t.string :main_model
      t.string :fallback_model
      t.string :cloned_from
      t.boolean :editable, default: true, null: false
      t.boolean :tool_sets_editable, default: true, null: false

      t.timestamps
    end
  end
end