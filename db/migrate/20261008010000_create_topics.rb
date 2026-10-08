class CreateTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :topics do |t|
      t.references :project, null: false, foreign_key: true
      t.references :parent_topic, foreign_key: { to_table: :topics }, null: true
      t.text :name, null: false
      t.text :related_topics
      t.boolean :active, null: false, default: true
      t.integer :importance_level
      t.text :memory
      t.text :state
      t.boolean :need_an_action, null: false, default: false
      t.text :required_actions

      t.timestamps
    end
  end
end
