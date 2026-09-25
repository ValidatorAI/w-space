require "rexml/document"

class SeedMcpsFromDefaultProfileXml < ActiveRecord::Migration[8.0]
  DEFAULT_PROFILE_MCP_NAMES = [
    "w-bridge",
    "Workspace memory",
    "obisidian"
  ].freeze

  def up
    return unless table_exists?(:mcps)

    now = Time.current

    parse_mcps_from_xml.each do |attributes|
      mcp = mcps_relation.find_or_initialize_by(name: attributes[:name])
      mcp.transport = attributes[:transport]
      mcp.url = attributes[:url]
      mcp.authentication = attributes[:authentication]
      mcp.bearer_token = attributes[:bearer_token]
      mcp.status = attributes[:status]
      mcp.created_at ||= now
      mcp.updated_at = now
      mcp.save! if mcp.new_record? || mcp.changed?
    end
  end

  def down
    return unless table_exists?(:mcps)

    mcps_relation.where(name: DEFAULT_PROFILE_MCP_NAMES).delete_all
  end

  private

  def parse_mcps_from_xml
    xml_path = Rails.root.join("..", "W-ai", "default-profile-mcp.xml")

    unless File.exist?(xml_path)
      raise "Missing XML MCP source at #{xml_path}"
    end

    document = REXML::Document.new(File.read(xml_path))

    document.elements.to_a("mcp_servers/mcp_server").map do |node|
      {
        name: normalize(node.elements["name"]&.text || node.attributes["name"]),
        transport: normalize(node.elements["transport"]&.text),
        url: normalize(node.elements["url"]&.text),
        authentication: normalize(node.elements["authentication"]&.text),
        bearer_token: normalize(node.elements["bearer_token"]&.text),
        status: normalize(node.elements["status"]&.text)
      }
    end.select { |attrs| attrs[:name].present? }
  end

  def normalize(value)
    text = value.to_s.strip
    text.present? ? text : nil
  end

  def mcps_relation
    @mcps_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "mcps"
    end
  end
end