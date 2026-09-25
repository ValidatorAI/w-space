require "rexml/document"

class SeedAiProfileRelationsFromHermesProfilesXml < ActiveRecord::Migration[8.0]
  def up
    return unless tables_available?

    now = Time.current

    each_profile_payload do |payload|
      profile_name = payload[:profile_name]
      next if profile_name.blank?

      ai_profile = ai_profiles_relation.find_by(profile_name: profile_name)
      next unless ai_profile

      seed_profile_skills(ai_profile.id, payload[:skills], now)
      seed_profile_tools(ai_profile.id, payload[:tools], now)
      seed_profile_mcps(ai_profile.id, payload[:mcps], now)
    end
  end

  def down
    return unless tables_available?

    profile_ids = ai_profiles_relation.where(profile_name: profile_names_from_xml).pluck(:id)
    return if profile_ids.empty?

    ai_profile_skills_relation.where(ai_profile_id: profile_ids).delete_all
    ai_profile_tools_relation.where(ai_profile_id: profile_ids).delete_all
    ai_profile_mcps_relation.where(ai_profile_id: profile_ids).delete_all
  end

  private

  def tables_available?
    table_exists?(:ai_profiles) &&
      table_exists?(:skills) &&
      table_exists?(:tools) &&
      table_exists?(:mcps) &&
      table_exists?(:ai_profile_skills) &&
      table_exists?(:ai_profile_tools) &&
      table_exists?(:ai_profile_mcps)
  end

  def seed_profile_skills(ai_profile_id, skill_names, now)
    skill_names.uniq.each do |skill_name|
      next if skill_name.blank?

      skill = skills_relation.find_or_initialize_by(name: skill_name)
      skill.category = nil if skill.category.nil?
      skill.description = nil if skill.description.nil?
      skill.skill_text = nil if skill.skill_text.nil?
      skill.add_by_default = false if skill.add_by_default.nil?
      skill.created_at ||= now
      skill.updated_at = now
      skill.save! if skill.new_record? || skill.changed?

      relation = ai_profile_skills_relation.find_or_initialize_by(
        ai_profile_id: ai_profile_id,
        skill_id: skill.id
      )
      relation.enabled = true
      relation.created_at ||= now
      relation.updated_at = now
      relation.save! if relation.new_record? || relation.changed?
    end
  end

  def seed_profile_tools(ai_profile_id, tool_names, now)
    tool_names.uniq.each do |tool_name|
      next if tool_name.blank?

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

  def seed_profile_mcps(ai_profile_id, mcp_entries, now)
    mcp_entries.each do |entry|
      mcp_name = entry[:name]
      next if mcp_name.blank?

      mcp = mcps_relation.find_or_initialize_by(name: mcp_name)

      mcp.transport = normalize_transport(entry[:transport], entry[:url]) if mcp.transport.blank?
      mcp.url = normalize_url(entry[:url], entry[:transport]) if mcp.url.blank?
      mcp.authentication = entry[:authentication].presence || "none" if mcp.authentication.blank?
      mcp.status = entry[:status].presence || "enabled" if mcp.status.blank?
      mcp.bearer_token = entry[:bearer_token] if mcp.bearer_token.blank? && entry[:bearer_token].present?
      mcp.created_at ||= now
      mcp.updated_at = now
      mcp.save! if mcp.new_record? || mcp.changed?

      relation = ai_profile_mcps_relation.find_or_initialize_by(
        ai_profile_id: ai_profile_id,
        mcp_id: mcp.id
      )
      relation.active = true
      relation.created_at ||= now
      relation.updated_at = now
      relation.save! if relation.new_record? || relation.changed?
    end
  end

  def each_profile_payload
    profile_xml_paths.each do |path|
      document = REXML::Document.new(File.read(path))
      document.elements.to_a("ai_config/profiles/profile").each do |profile_node|
        yield payload_from_node(profile_node)
      end
    end
  end

  def payload_from_node(profile_node)
    {
      profile_name: normalize(profile_node.attributes["name"] || profile_node.elements["name"]&.text),
      skills: parse_skill_names(profile_node),
      tools: parse_tool_names(profile_node),
      mcps: parse_mcp_entries(profile_node)
    }
  end

  def parse_skill_names(node)
    node.elements.to_a("skills/skill").map do |skill_node|
      normalize(skill_node.attributes["name"] || skill_node.elements["name"]&.text)
    end.compact
  end

  def parse_tool_names(node)
    node.elements.to_a("tools/tool").map do |tool_node|
      normalize(tool_node.attributes["name"] || tool_node.elements["name"]&.text)
    end.compact
  end

  def parse_mcp_entries(node)
    node.elements.to_a("mcps/mcp").map do |mcp_node|
      transport_value = normalize(mcp_node.attributes["transport"] || mcp_node.elements["transport"]&.text)
      url_value = normalize(mcp_node.attributes["url"] || mcp_node.elements["url"]&.text)
      auth_value = normalize(mcp_node.attributes["authentication"] || mcp_node.elements["authentication"]&.text)

      {
        name: normalize(mcp_node.attributes["name"] || mcp_node.elements["name"]&.text),
        transport: transport_value,
        url: url_value,
        authentication: auth_value,
        status: normalize(mcp_node.attributes["status"] || mcp_node.elements["status"]&.text),
        bearer_token: normalize(mcp_node.attributes["bearer_token"] || mcp_node.elements["bearer_token"]&.text)
      }
    end
  end

  def profile_names_from_xml
    names = []

    each_profile_payload do |payload|
      name = payload[:profile_name]
      names << name if name.present?
    end

    names.uniq
  end

  def profile_xml_paths
    xml_path = Rails.root.join("config", "ai", "ai_config.xml")

    unless File.exist?(xml_path)
      raise "No profile XML files found at #{xml_path}"
    end

    [xml_path]
  end

  def normalize_transport(transport, url)
    return transport unless transport.blank? || transport.start_with?("http://", "https://")
    return "http" if url.to_s.start_with?("http://", "https://")

    "http"
  end

  def normalize_url(url, transport)
    return url if url.present?
    return transport if transport.to_s.start_with?("http://", "https://")

    "http://127.0.0.1:0/mcp"
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

  def skills_relation
    @skills_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "skills"
    end
  end

  def tools_relation
    @tools_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "tools"
    end
  end

  def mcps_relation
    @mcps_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "mcps"
    end
  end

  def ai_profile_skills_relation
    @ai_profile_skills_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_profile_skills"
    end
  end

  def ai_profile_tools_relation
    @ai_profile_tools_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_profile_tools"
    end
  end

  def ai_profile_mcps_relation
    @ai_profile_mcps_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_profile_mcps"
    end
  end
end
