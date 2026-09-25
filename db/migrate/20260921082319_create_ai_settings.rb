class CreateAiSettings < ActiveRecord::Migration[8.2]
  def change
    create_table :ai_settings do |t|
      t.string :label
      t.integer :setting_value

      t.timestamps
    end
  end
end
