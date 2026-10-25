class RenameProjectObsidianNotesToProjectNotes < ActiveRecord::Migration[8.0]
  def up
    rename_table :project_obsidian_notes, :project_notes

    if index_name_exists?(:project_notes, :index_project_obsidian_notes_on_project_id)
      rename_index :project_notes, :index_project_obsidian_notes_on_project_id, :index_project_notes_on_project_id
    end

    if index_name_exists?(:project_notes, :index_project_obsidian_notes_on_position)
      rename_index :project_notes, :index_project_obsidian_notes_on_position, :index_project_notes_on_position
    end
  end

  def down
    if index_name_exists?(:project_notes, :index_project_notes_on_project_id)
      rename_index :project_notes, :index_project_notes_on_project_id, :index_project_obsidian_notes_on_project_id
    end

    if index_name_exists?(:project_notes, :index_project_notes_on_position)
      rename_index :project_notes, :index_project_notes_on_position, :index_project_obsidian_notes_on_position
    end

    rename_table :project_notes, :project_obsidian_notes
  end
end
