class DisableTerminalAndFileToolsForNonExemptProfiles < ActiveRecord::Migration[8.0]
  ALLOWED_PROFILE_NAMES = %w[coder delegator default config].freeze
  TOOL_NAMES = %w[file terminal].freeze

  def up
    return unless tables_available?

    tool_ids = tools_relation.where(name: TOOL_NAMES).pluck(:id)
    return if tool_ids.empty?

    profile_ids = ai_profiles_relation.where(profile_name: ALLOWED_PROFILE_NAMES).pluck(:id)

    if profile_ids.any?
      ai_profile_tools_relation
        .where(tool_id: tool_ids)
        .where(ai_profile_id: profile_ids)
        .update_all(enabled: true)

      ai_profile_tools_relation
        .where(tool_id: tool_ids)
        .where.not(ai_profile_id: profile_ids)
        .update_all(enabled: false)
    else
      ai_profile_tools_relation
        .where(tool_id: tool_ids)
        .update_all(enabled: false)
    end
  end

  def down
    return unless tables_available?

    tool_ids = tools_relation.where(name: TOOL_NAMES).pluck(:id)
    return if tool_ids.empty?

    ai_profile_tools_relation.where(tool_id: tool_ids).update_all(enabled: true)
  end

  private

  def tables_available?
    table_exists?(:ai_profiles) &&
      table_exists?(:tools) &&
      table_exists?(:ai_profile_tools)
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
