class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.text :adder_profile
      t.integer :token_used
      t.integer :token_budget
      t.integer :room_id
      t.integer :project_id
      t.text :description, null: false
      t.text :assigneee_profile
      t.boolean :added_to_kanban, null: false, default: false
      t.boolean :runned, null: false, default: false
      t.integer :parent_task_id
      t.integer :importance, null: false, default: 0
      t.integer :level, null: false, default: 0

      t.timestamps
    end

    add_index :tasks, :project_id
    add_index :tasks, :room_id
    add_index :tasks, :parent_task_id
  end
end
