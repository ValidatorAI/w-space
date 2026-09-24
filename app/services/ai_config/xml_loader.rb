require "rexml/document"
require "set"

module AiConfig
  class XmlLoader
    class ConfigError < StandardError; end

    SOURCE_PATH = Rails.root.join("config", "ai", "ai_config.xml").freeze

    BOT_PROFILE_NAMES = %w[
      project_manager
      business_analyst
      market_research
      coder
      ask_from_w
    ].freeze

    BOOLEAN_TRUE_VALUES = %w[1 true yes on].freeze
    BOOLEAN_FALSE_VALUES = %w[0 false no off].freeze

    def initialize(source_path: SOURCE_PATH)
      @source_path = Pathname.new(source_path)
    end

    def load
      root = parse_document.root
      raise ConfigError, "Root element must be <ai_config>" unless root&.name == "ai_config"

      tools = parse_tools(root)
      skills = parse_skills(root)
      mcps = parse_mcps(root)
      profiles = parse_profiles(root)

      validate_uniqueness!(tools.map { |row| row.fetch(:name) }, "tool names")
      validate_uniqueness!(skills.map { |row| row.fetch(:name) }, "skill names")
      validate_uniqueness!(mcps.map { |row| row.fetch(:name) }, "MCP names")
      validate_uniqueness!(profiles.map { |row| row.fetch(:profile_name) }, "profile names")

      validate_profile_references!(profiles: profiles, tools: tools, skills: skills, mcps: mcps)

      {
        tools: tools,
        skills: skills,
        mcps: mcps,
        profiles: profiles
      }
    end

    private

    attr_reader :source_path

    def parse_document
      raise ConfigError, "Missing AI config XML at #{source_path}" unless File.exist?(source_path)

      REXML::Document.new(File.read(source_path))
    rescue REXML::ParseException => error
      raise ConfigError, "Invalid AI config XML: #{error.message}"
    end

    def parse_tools(root)
      nodes = root.elements.to_a("tools/tool")
      raise ConfigError, "XML is missing tool definitions under <tools>" if nodes.empty?

      nodes.map do |node|
        name = parse_name(node)
        raise ConfigError, "Tool entry missing name" if name.blank?

        {
          name: name,
          active: parse_boolean(node.elements["active"]&.text || node.attributes["active"], default: true)
        }
      end
    end

    def parse_skills(root)
      nodes = root.elements.to_a("skills/skill")
      raise ConfigError, "XML is missing skill definitions under <skills>" if nodes.empty?

      nodes.map do |node|
        name = parse_name(node)
        raise ConfigError, "Skill entry missing name" if name.blank?

        {
          name: name,
          category: normalize(node.elements["category"]&.text || node.attributes["category"]),
          description: normalize(node.elements["description"]&.text),
          skill_text: normalize(node.elements["skill_text"]&.text),
          add_by_default: parse_boolean(
            node.elements["add_by_default"]&.text || node.attributes["add_by_default"],
            default: false
          )
        }
      end
    end

    def parse_mcps(root)
      nodes = root.elements.to_a("mcps/mcp")
      raise ConfigError, "XML is missing MCP definitions under <mcps>" if nodes.empty?

      nodes.map do |node|
        name = parse_name(node)
        raise ConfigError, "MCP entry missing name" if name.blank?

        raw_transport = normalize(node.elements["transport"]&.text || node.attributes["transport"])
        raw_url = normalize(node.elements["url"]&.text || node.attributes["url"])

        transport = normalize_transport(raw_transport, raw_url)

        {
          name: name,
          transport: transport,
          url: normalize_url(raw_url, transport),
          authentication: normalize_authentication(
            node.elements["authentication"]&.text || node.attributes["authentication"],
            transport
          ),
          bearer_token: normalize(node.elements["bearer_token"]&.text || node.attributes["bearer_token"]),
          status: normalize_status(node.elements["status"]&.text || node.attributes["status"]),
          command: normalize(node.elements["command"]&.text || node.attributes["command"]),
          args: normalize(node.elements["args"]&.text || node.attributes["args"]),
          environment: normalize(node.elements["environment"]&.text || node.attributes["environment"])
        }
      end
    end

    def parse_profiles(root)
      nodes = root.elements.to_a("profiles/profile")
      raise ConfigError, "XML is missing profile definitions under <profiles>" if nodes.empty?

      nodes.map do |node|
        profile_name = normalize(node.attributes["name"] || node.elements["profile_name"]&.text || node.elements["name"]&.text)
        raise ConfigError, "Profile entry missing profile name" if profile_name.blank?

        {
          profile_name: profile_name,
          soul: normalize(node.elements["soul"]&.text || node.elements["soul_md"]&.text),
          bot: parse_boolean(node.elements["bot"]&.text || node.attributes["bot"], default: BOT_PROFILE_NAMES.include?(profile_name)),
          bot_name: normalize(node.elements["bot_name"]&.text || node.attributes["bot_name"]),
          editable: parse_boolean(node.elements["editable"]&.text || node.attributes["editable"], default: true),
          tool_sets_editable: parse_boolean(
            node.elements["tool_sets_editable"]&.text || node.attributes["tool_sets_editable"],
            default: true
          ),
          max_line_sessions: parse_integer(node.elements["max_line_sessions"]&.text, default: AiProfile::SESSION_LIMIT_DEFAULT),
          max_concurrent_sessions: parse_integer(node.elements["max_concurrent_sessions"]&.text, default: AiProfile::SESSION_LIMIT_DEFAULT),
          auto_decompose_per_tick: parse_integer(node.elements["auto_decompose_per_tick"]&.text, default: AiProfile::SESSION_LIMIT_DEFAULT),
          max_in_progress_per_profile: parse_integer(node.elements["max_in_progress_per_profile"]&.text, default: AiProfile::SESSION_LIMIT_DEFAULT),
          max_number_of_workers: parse_integer(node.elements["max_number_of_workers"]&.text, default: AiProfile::WORKER_LIMIT_DEFAULT),
          max_spawn_depth: parse_integer(node.elements["max_spawn_depth"]&.text, default: AiProfile::SPAWN_DEPTH_DEFAULT),
          main_model: normalize(node.elements["main_model"]&.text),
          fallback_model: normalize(node.elements["fallback_model"]&.text),
          cloned_from: normalize(node.elements["cloned_from"]&.text),
          tools: parse_relation_names(node, "tools/tool"),
          skills: parse_relation_names(node, "skills/skill"),
          mcps: parse_relation_names(node, "mcps/mcp")
        }
      end
    end

    def parse_relation_names(profile_node, path)
      profile_node
        .elements
        .to_a(path)
        .map { |node| parse_name(node) }
        .compact
        .uniq
    end

    def parse_name(node)
      normalize(node.attributes["name"] || node.elements["name"]&.text || node.text)
    end

    def normalize_transport(transport, url)
      normalized = normalize(transport)

      if normalized.present? && normalized.start_with?("http://", "https://")
        return "http"
      end

      return "http" if normalized.blank? && url.present?

      normalized.presence || "http"
    end

    def normalize_url(url, transport)
      return "" if transport == "stdio"

      normalize(url).presence || "http://127.0.0.1:0/mcp"
    end

    def normalize_authentication(authentication, transport)
      return "none" if transport == "stdio"

      normalized = normalize(authentication)&.downcase
      return "none" if normalized.blank?
      return "bearer" if %w[bearer token].include?(normalized)

      normalized
    end

    def normalize_status(status)
      normalized = normalize(status)&.downcase
      return "active" if normalized.blank?
      return "active" if %w[active enabled true 1].include?(normalized)
      return "inactive" if %w[inactive disabled false 0].include?(normalized)

      normalized
    end

    def parse_boolean(value, default:)
      normalized = normalize(value)&.downcase
      return default if normalized.blank?
      return true if BOOLEAN_TRUE_VALUES.include?(normalized)
      return false if BOOLEAN_FALSE_VALUES.include?(normalized)

      default
    end

    def parse_integer(value, default:)
      number = Integer(value)
      number.positive? ? number : default
    rescue ArgumentError, TypeError
      default
    end

    def validate_uniqueness!(values, label)
      duplicates = values.group_by(&:itself).select { |_value, rows| rows.length > 1 }.keys
      return if duplicates.empty?

      raise ConfigError, "Duplicate #{label}: #{duplicates.join(', ')}"
    end

    def validate_profile_references!(profiles:, tools:, skills:, mcps:)
      tool_names = tools.map { |row| row.fetch(:name) }.to_set
      skill_names = skills.map { |row| row.fetch(:name) }.to_set
      mcp_names = mcps.map { |row| row.fetch(:name) }.to_set

      profiles.each do |profile|
        validate_reference_list!(
          profile_name: profile.fetch(:profile_name),
          kind: "tools",
          values: profile.fetch(:tools),
          allowed: tool_names
        )

        validate_reference_list!(
          profile_name: profile.fetch(:profile_name),
          kind: "skills",
          values: profile.fetch(:skills),
          allowed: skill_names
        )

        validate_reference_list!(
          profile_name: profile.fetch(:profile_name),
          kind: "MCPs",
          values: profile.fetch(:mcps),
          allowed: mcp_names
        )
      end
    end

    def validate_reference_list!(profile_name:, kind:, values:, allowed:)
      missing = values.reject { |name| allowed.include?(name) }
      return if missing.empty?

      raise ConfigError, "Profile '#{profile_name}' references unknown #{kind}: #{missing.join(', ')}"
    end

    def normalize(value)
      text = value.to_s.strip
      text.present? ? text : nil
    end
  end
end
