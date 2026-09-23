class RefreshAiProfilesFromWAiSouls < ActiveRecord::Migration[8.0]
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
      profile = ai_profiles_relation.find_or_initialize_by(profile_name: source.fetch(:profile_name))

      profile.soul = soul_text_for(source.fetch(:dirs))
      profile.bot = source.fetch(:bot)
      profile.bot_name = profile.bot ? humanized_bot_name(profile.profile_name) : nil
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

  def soul_text_for(dir_candidates)
    soul_path = resolve_soul_path(dir_candidates)
    normalize(File.read(soul_path))
  end

  def resolve_soul_path(dir_candidates)
    attempted = []

    dir_candidates.each do |segments|
      ["SOUL.md", "SOUL.MD"].each do |filename|
        candidate = Rails.root.join("..", "W-ai", "hermes", "profiles", *segments, filename)
        attempted << candidate.to_s
        return candidate if File.exist?(candidate)
      end
    end

    raise "Profile soul file not found. Tried: #{attempted.join(', ')}"
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
