class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.string :name, null: false
      t.string :category
      t.text :skill_text
      t.boolean :add_by_default, default: false, null: false

      t.timestamps
    end
  end
end
