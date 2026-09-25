class RefreshAiProfilesFromWAiHermesSouls < ActiveRecord::Migration[8.0]
  PROFILE_SOURCES = [
    { profile_name: "action", dirs: [["main", "action"]], bot: false },
    { profile_name: "company", dirs: [["main", "company"]], bot: false },
    { profile_name: "company_project", dirs: [["main", "company_project"]], bot: false },
    { profile_name: "config", dirs: [["main", "config"], ["se", "config"]], bot: false },
    { profile_name: "cron_profile", dirs: [["main", "cron_profile"]], bot: false },
    { profile_name: "delegator", dirs: [["main", "delegator"]], bot: false },
    { profile_name: "knowledge", dirs: [["main", "knowledge"]], bot: false },
    { profile_name: "normal_message", dirs: [["main", "normal message"]], bot: false },
    { profile_name: "not_known_task", dirs: [["main", "not_known_task"]], bot: false },
    { profile_name: "ask_from_w", dirs: [["bots", "ask from w"]], bot: true },
    { profile_name: "business_analyst", dirs: [["bots", "business analyst"]], bot: true },
    { profile_name: "coder", dirs: [["bots", "coder"]], bot: true },
    { profile_name: "market_research", dirs: [["bots", "market research"]], bot: true },
    { profile_name: "project_manager", dirs: [["bots", "project manager"]], bot: true }
  ].freeze

  def up
    return unless table_exists?(:ai_profiles)

    now = Time.current

    PROFILE_SOURCES.each do |source|
      profile_name = source.fetch(:profile_name)
      profile = ai_profiles_relation.find_or_initialize_by(profile_name: profile_name)

      profile.soul = soul_text_for(profile_name)
      profile.bot = source.fetch(:bot)
      profile.bot_name = profile.bot ? humanized_bot_name(profile_name) : nil
      profile.editable = true if profile.editable.nil?
      profile.tool_sets_editable = true if profile.tool_sets_editable.nil?
      profile.created_at ||= now
      profile.updated_at = now
      profile.save! if profile.new_record? || profile.changed?
    end
  end

  def down
    # Intentional no-op: this migration refreshes profile souls from source-of-truth.
  end

  private

  def soul_text_for(profile_name)
    xml_path = Rails.root.join("config", "ai", "ai_config.xml")
    raise "Config AI file not found at #{xml_path}" unless File.exist?(xml_path)

    document = REXML::Document.new(File.read(xml_path))
    soul = document.elements["ai_config/profiles/profile[@name='#{profile_name}']/soul"]
    raise "Soul for profile #{profile_name} not found in #{xml_path}" unless soul

    normalize(soul.text)
  end

  def humanized_bot_name(profile_name)
    profile_name.tr("_-", " ").split.map(&:capitalize).join(" ")
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
end
