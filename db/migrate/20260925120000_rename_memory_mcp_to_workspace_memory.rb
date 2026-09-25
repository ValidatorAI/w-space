class RenameMemoryMcpToWorkspaceMemory < ActiveRecord::Migration[8.0]
  OLD_NAME = "memory".freeze
  NEW_NAME = "Workspace memory".freeze

  def up
    return unless table_exists?(:mcps)

    Mcp::Server.where(name: OLD_NAME).update_all(name: NEW_NAME)
  end

  def down
    return unless table_exists?(:mcps)

    Mcp::Server.where(name: NEW_NAME).update_all(name: OLD_NAME)
  end
end
