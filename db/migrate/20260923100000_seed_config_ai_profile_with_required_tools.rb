class SeedConfigAiProfileWithRequiredTools < ActiveRecord::Migration[8.0]
  PROFILE_NAME = "config".freeze
  REQUIRED_TOOL_NAMES = %w[
    terminal
    file
    skills
    todo
    memory
    session_search
    delegation
    clarify
  ].freeze

  def up
    return unless tables_available?

    now = Time.current
    profile = ai_profiles_relation.find_or_initialize_by(profile_name: PROFILE_NAME)

    profile.soul = config_soul_text
    profile.bot = false
    profile.bot_name = nil
    profile.main_model = nil if profile.main_model.nil?
    profile.fallback_model = nil if profile.fallback_model.nil?
    profile.cloned_from = nil if profile.cloned_from.nil?
    profile.editable = true if profile.editable.nil?
    profile.tool_sets_editable = true if profile.tool_sets_editable.nil?
    profile.created_at ||= now
    profile.updated_at = now
    profile.save! if profile.new_record? || profile.changed?

    seed_required_tools(profile.id, now)
  end

  def down
    return unless table_exists?(:ai_profiles)

    profile = ai_profiles_relation.find_by(profile_name: PROFILE_NAME)
    return unless profile

    if table_exists?(:ai_profile_tools)
      ai_profile_tools_relation.where(ai_profile_id: profile.id).delete_all
    end

    profile.delete
  end

  private

  def tables_available?
    table_exists?(:ai_profiles) &&
      table_exists?(:tools) &&
      table_exists?(:ai_profile_tools)
  end

  def config_soul_text
    primary_path = Rails.root.join("..", "W-ai", "hermes", "profiles", "main", "config", "SOUL.md")
    secondary_path = Rails.root.join("..", "W-ai", "hermes", "profiles", "se", "config", "SOUL.md")

    soul_path = if File.exist?(primary_path)
      primary_path
    elsif File.exist?(secondary_path)
      secondary_path
    else
      raise "Config soul file not found at #{primary_path} or #{secondary_path}"
    end

    normalize(File.read(soul_path))
  end

  def seed_required_tools(ai_profile_id, now)
    REQUIRED_TOOL_NAMES.each do |tool_name|
      tool = tools_relation.find_or_initialize_by(name: tool_name)
      tool.active = true if tool.active.nil?
      tool.created_at ||= now
      tool.updated_at = now
      tool.save! if tool.new_record? || tool.changed?

      relation = ai_profile_tools_relation.find_or_initialize_by(
        ai_profile_id: ai_profile_id,
        tool_id: tool.id
      )
      relation.enabled = true
      relation.created_at ||= now
      relation.updated_at = now
      relation.save! if relation.new_record? || relation.changed?
    end
  end

  def normalize(value)
    text = value.to_s.strip
    text.present? ? text : nil
  end

  def ai_profiles_relation
    @ai_profiles_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_profiles"
    end
  end

  def tools_relation
    @tools_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "tools"
    end
  end

  def ai_profile_tools_relation
    @ai_profile_tools_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_profile_tools"
    end
  end
end
