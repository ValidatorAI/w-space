class RenameTasksToAiTasks < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:ai_tasks)

    rename_table :tasks, :ai_tasks

    if index_exists?(:ai_tasks, :project_id, name: "index_tasks_on_project_id")
      rename_index :ai_tasks, "index_tasks_on_project_id", "index_ai_tasks_on_project_id"
    end
    if index_exists?(:ai_tasks, :room_id, name: "index_tasks_on_room_id")
      rename_index :ai_tasks, "index_tasks_on_room_id", "index_ai_tasks_on_room_id"
    end
    if index_exists?(:ai_tasks, :parent_task_id, name: "index_tasks_on_parent_task_id")
      rename_index :ai_tasks, "index_tasks_on_parent_task_id", "index_ai_tasks_on_parent_task_id"
    end
    if index_exists?(:ai_tasks, :grand_parent_id, name: "index_tasks_on_grand_parent_id")
      rename_index :ai_tasks, "index_tasks_on_grand_parent_id", "index_ai_tasks_on_grand_parent_id"
    end
  end

  def down
    return if table_exists?(:tasks)

    rename_table :ai_tasks, :tasks

    if index_exists?(:tasks, :project_id, name: "index_ai_tasks_on_project_id")
      rename_index :tasks, "index_ai_tasks_on_project_id", "index_tasks_on_project_id"
    end
    if index_exists?(:tasks, :room_id, name: "index_ai_tasks_on_room_id")
      rename_index :tasks, "index_ai_tasks_on_room_id", "index_tasks_on_room_id"
    end
    if index_exists?(:tasks, :parent_task_id, name: "index_ai_tasks_on_parent_task_id")
      rename_index :tasks, "index_ai_tasks_on_parent_task_id", "index_tasks_on_parent_task_id"
    end
    if index_exists?(:tasks, :grand_parent_id, name: "index_ai_tasks_on_grand_parent_id")
      rename_index :tasks, "index_ai_tasks_on_grand_parent_id", "index_tasks_on_grand_parent_id"
    end
  end
end
