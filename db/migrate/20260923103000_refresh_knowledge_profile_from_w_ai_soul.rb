class RefreshKnowledgeProfileFromWAiSoul < ActiveRecord::Migration[8.0]
  PROFILE_NAME = "knowledge".freeze

  def up
    return unless table_exists?(:ai_profiles)

    profile = ai_profiles_relation.find_or_initialize_by(profile_name: PROFILE_NAME)
    now = Time.current

    profile.soul = knowledge_soul_text
    profile.bot = false
    profile.bot_name = nil
    profile.editable = true if profile.editable.nil?
    profile.tool_sets_editable = true if profile.tool_sets_editable.nil?
    profile.created_at ||= now
    profile.updated_at = now
    profile.save! if profile.new_record? || profile.changed?
  end

  def down
    # Intentional no-op: this migration refreshes knowledge soul from source-of-truth.
  end

  private

  def knowledge_soul_text
    soul_path = resolve_soul_path
    normalize(File.read(soul_path))
  end

  def resolve_soul_path
    candidates = [
      Rails.root.join("..", "W-ai", "hermes", "profiles", "main", "knowledge", "SOUL.md"),
      Rails.root.join("..", "W-ai", "hermes", "profiles", "main", "knowledge", "SOUL.MD")
    ]

    candidates.find { |path| File.exist?(path) } ||
      raise("Knowledge soul file not found. Tried: #{candidates.map(&:to_s).join(', ')}")
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
