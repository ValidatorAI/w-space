class CreateProjectMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :project_milestones, if_not_exists: true do |t|
      t.integer :project_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :icon, default: "✅"
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :project_milestones, :project_id unless index_exists?(:project_milestones, :project_id)
    add_index :project_milestones, :position unless index_exists?(:project_milestones, :position)
    add_foreign_key :project_milestones, :projects unless foreign_key_exists?(:project_milestones, :projects)
  end
end
