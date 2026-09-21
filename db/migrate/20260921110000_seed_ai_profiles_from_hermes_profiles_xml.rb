require "rexml/document"

class SeedAiProfilesFromHermesProfilesXml < ActiveRecord::Migration[8.0]
  BOT_PROFILE_NAMES = %w[
    project_manager
    business_analyst
    market_research
    coder
    ask_from_w
  ].freeze

  def up
    return unless table_exists?(:ai_profiles)

    now = Time.current

    each_profile_document do |document|
      attributes = parse_profile_attributes(document)
      profile_name = attributes[:profile_name]
      next if profile_name.blank?

      profile = ai_profiles_relation.find_or_initialize_by(profile_name: profile_name)
      profile.soul = attributes[:soul]
      profile.bot = BOT_PROFILE_NAMES.include?(profile_name)
      profile.bot_name = profile.bot ? humanized_bot_name(profile_name) : nil
      profile.main_model = nil
      profile.fallback_model = nil
      profile.cloned_from = nil
      profile.editable = true if profile.editable.nil?
      profile.tool_sets_editable = true if profile.tool_sets_editable.nil?
      profile.created_at ||= now
      profile.updated_at = now
      profile.save! if profile.new_record? || profile.changed?
    end
  end

  def down
    return unless table_exists?(:ai_profiles)

    ai_profiles_relation.where(profile_name: profile_names_from_xml).delete_all
  end

  private

  def parse_profile_attributes(document)
    root = document.root

    {
      profile_name: normalize(root.attributes["name"] || root.elements["name"]&.text),
      soul: normalize(root.elements["soul_md"]&.text)
    }
  end

  def profile_names_from_xml
    names = []

    each_profile_document do |document|
      name = parse_profile_attributes(document)[:profile_name]
      names << name if name.present?
    end

    names.uniq
  end

  def each_profile_document
    profile_xml_paths.each do |path|
      yield REXML::Document.new(File.read(path))
    end
  end

  def profile_xml_paths
    pattern = Rails.root.join("..", "W-ai", "hermes-profiles-xml", "*.xml")
    paths = Dir.glob(pattern.to_s).sort

    if paths.empty?
      raise "No profile XML files found at #{pattern}"
    end

    paths
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
