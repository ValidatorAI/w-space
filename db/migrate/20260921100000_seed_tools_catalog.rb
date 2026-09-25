class SeedToolsCatalog < ActiveRecord::Migration[8.0]
  TOOL_ACTIVE_STATES = {
    "web" => true,
    "browser" => true,
    "terminal" => true,
    "file" => true,
    "code_execution" => true,
    "vision" => false,
    "video" => false,
    "image_gen" => false,
    "video_gen" => false,
    "bfl" => false,
    "x_search" => false,
    "tts" => false,
    "stt" => true,
    "skills" => true,
    "todo" => true,
    "memory" => true,
    "context_engine" => false,
    "session_search" => true,
    "clarify" => true,
    "delegation" => true,
    "cronjob" => true,
    "homeassistant" => false,
    "spotify" => false,
    "discord" => false,
    "discord_admin" => false,
    "yuanbao" => false,
    "computer_use" => false,
    "a2a" => false
  }.freeze

  def up
    return unless table_exists?(:tools)

    TOOL_ACTIVE_STATES.each do |name, active|
      tool = tools_relation.find_or_initialize_by(name: name)
      tool.active = active
      tool.save! if tool.new_record? || tool.changed?
    end
  end

  def down
    return unless table_exists?(:tools)

    tools_relation.where(name: TOOL_ACTIVE_STATES.keys).delete_all
  end

  private

  def tools_relation
    @tools_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "tools"
    end
  end
end