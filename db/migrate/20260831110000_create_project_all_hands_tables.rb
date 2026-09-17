class CreateProjectAllHandsTables < ActiveRecord::Migration[8.0]
  def change
    create_table :project_all_hands_takeaways, if_not_exists: true do |t|
      t.integer :project_id, null: false
      t.string :category, null: false
      t.text :content, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :project_all_hands_takeaways, :project_id unless index_exists?(:project_all_hands_takeaways, :project_id)
    add_index :project_all_hands_takeaways, :position unless index_exists?(:project_all_hands_takeaways, :position)
    add_foreign_key :project_all_hands_takeaways, :projects unless foreign_key_exists?(:project_all_hands_takeaways, :projects)

    create_table :project_all_hands_action_items, if_not_exists: true do |t|
      t.integer :project_id, null: false
      t.string :title, null: false
      t.string :assignee_name
      t.string :due_date
      t.boolean :completed, default: false, null: false
      t.boolean :active, default: true, null: false
      t.datetime :completed_at
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :project_all_hands_action_items, :project_id unless index_exists?(:project_all_hands_action_items, :project_id)
    add_index :project_all_hands_action_items, :position unless index_exists?(:project_all_hands_action_items, :position)
    add_foreign_key :project_all_hands_action_items, :projects unless foreign_key_exists?(:project_all_hands_action_items, :projects)

    create_table :project_all_hands_decisions, if_not_exists: true do |t|
      t.integer :project_id, null: false
      t.string :title, null: false
      t.string :basis
      t.string :impact
      t.string :badge, default: "Logged in System"
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :project_all_hands_decisions, :project_id unless index_exists?(:project_all_hands_decisions, :project_id)
    add_index :project_all_hands_decisions, :position unless index_exists?(:project_all_hands_decisions, :position)
    add_foreign_key :project_all_hands_decisions, :projects unless foreign_key_exists?(:project_all_hands_decisions, :projects)
  end
end
