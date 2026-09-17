class AddActiveToProjectKnowledgeTables < ActiveRecord::Migration[8.0]
  def change
    add_column :project_knowledge_items, :active, :boolean, default: true, null: false unless column_exists?(:project_knowledge_items, :active)
    add_column :project_obsidian_notes, :active, :boolean, default: true, null: false unless column_exists?(:project_obsidian_notes, :active)
    add_column :project_external_assets, :active, :boolean, default: true, null: false unless column_exists?(:project_external_assets, :active)
    add_column :project_adrs, :active, :boolean, default: true, null: false unless column_exists?(:project_adrs, :active)
    add_column :project_knowledge_activities, :active, :boolean, default: true, null: false unless column_exists?(:project_knowledge_activities, :active)
    add_column :project_directory_items, :active, :boolean, default: true, null: false unless column_exists?(:project_directory_items, :active)
  end
end
