class RenameAiTaskStatusColumns < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:ai_tasks)

    if column_exists?(:ai_tasks, :added_to_kanban) && !column_exists?(:ai_tasks, :dispatched)
      rename_column :ai_tasks, :added_to_kanban, :dispatched
    end

    if column_exists?(:ai_tasks, :runned) && !column_exists?(:ai_tasks, :finished)
      rename_column :ai_tasks, :runned, :finished
    end
  end

  def down
    return unless table_exists?(:ai_tasks)

    if column_exists?(:ai_tasks, :dispatched) && !column_exists?(:ai_tasks, :added_to_kanban)
      rename_column :ai_tasks, :dispatched, :added_to_kanban
    end

    if column_exists?(:ai_tasks, :finished) && !column_exists?(:ai_tasks, :runned)
      rename_column :ai_tasks, :finished, :runned
    end
  end
end
