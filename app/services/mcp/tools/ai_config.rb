module Mcp
  module Tools
    module AiConfig
      # Profiles
      class ListAiProfilesTool < Mcp::BaseTool
        def name = "list_ai_profiles"
        def description = "List all AI profiles"
        def aliases = ["ListAiProfiles"]
        def input_schema = { type: "object", properties: {} }
        def execute(_args) = success(AiProfile.order(:profile_name).map(&:as_json))
      end

      class GetAiProfileTool < Mcp::BaseTool
        def name = "get_ai_profile"
        def description = "Get a single AI profile"
        def aliases = ["GetAiProfile"]
        def input_schema = { type: "object", properties: { profile_id: { type: %w[string integer] }, profile_name: { type: "string" } } }
        def execute(args)
          profile = if args[:profile_id].present?
                      AiProfile.find(args[:profile_id])
                    else
                      AiProfile.find_by!(profile_name: args[:profile_name])
                    end
          success(profile.as_json)
        end
      end

      # Settings
      class ListAiSettingsTool < Mcp::BaseTool
        def name = "list_ai_settings"
        def description = "List all AI settings"
        def aliases = ["ListAiSettings"]
        def input_schema = { type: "object", properties: {} }
        def execute(_args) = success(AiSetting.all.map(&:as_json))
      end

      class GetAiSettingTool < Mcp::BaseTool
        def name = "get_ai_setting"
        def description = "Get a single AI setting"
        def aliases = ["GetAiSetting"]
        def input_schema = { type: "object", properties: { setting_id: { type: %w[string integer] } }, required: ["setting_id"] }
        def execute(args) = success(AiSetting.find(args[:setting_id]).as_json)
      end

      # MCP Servers
      class ListMcpsTool < Mcp::BaseTool
        def name = "list_mcps"
        def description = "List configured MCP servers"
        def aliases = ["ListMcps"]
        def input_schema = { type: "object", properties: {} }
        def execute(_args) = success(Mcp::Server.all.map(&:as_json))
      end

      class GetMcpTool < Mcp::BaseTool
        def name = "get_mcp"
        def description = "Get a single configured MCP server"
        def aliases = ["GetMcp"]
        def input_schema = { type: "object", properties: { mcp_id: { type: %w[string integer] } }, required: ["mcp_id"] }
        def execute(args) = success(Mcp::Server.find(args[:mcp_id]).as_json)
      end

      # Tools
      class ListToolsTool < Mcp::BaseTool
        def name = "list_tools"
        def description = "List registered AI tools"
        def aliases = ["ListTools"]
        def input_schema = { type: "object", properties: {} }
        def execute(_args) = success(Tool.all.map(&:as_json))
      end

      class GetToolTool < Mcp::BaseTool
        def name = "get_tool"
        def description = "Get a single registered AI tool"
        def aliases = ["GetTool"]
        def input_schema = { type: "object", properties: { tool_id: { type: %w[string integer] } }, required: ["tool_id"] }
        def execute(args) = success(Tool.find(args[:tool_id]).as_json)
      end

      # Skills
      class ListSkillsTool < Mcp::BaseTool
        def name = "list_skills"
        def description = "List registered AI skills"
        def aliases = ["ListSkills"]
        def input_schema = { type: "object", properties: {} }
        def execute(_args) = success(Skill.all.map(&:as_json))
      end

      class GetSkillTool < Mcp::BaseTool
        def name = "get_skill"
        def description = "Get a single registered AI skill"
        def aliases = ["GetSkill"]
        def input_schema = { type: "object", properties: { skill_id: { type: %w[string integer] } }, required: ["skill_id"] }
        def execute(args) = success(Skill.find(args[:skill_id]).as_json)
      end

      # Profile Tool assignments
      class ListAiProfileToolsTool < Mcp::BaseTool
        def name = "list_ai_profile_tools"
        def description = "List AI profile-tool assignments"
        def aliases = ["ListAiProfileTools"]
        def input_schema = { type: "object", properties: { ai_profile_id: { type: %w[string integer] }, tool_id: { type: %w[string integer] } } }
        def execute(args)
          scope = AiProfileTool.all
          scope = scope.where(ai_profile_id: args[:ai_profile_id]) if args[:ai_profile_id].present?
          scope = scope.where(tool_id: args[:tool_id]) if args[:tool_id].present?
          success(scope.map(&:as_json))
        end
      end

      class GetAiProfileToolTool < Mcp::BaseTool
        def name = "get_ai_profile_tool"
        def description = "Get a single AI profile-tool assignment"
        def aliases = ["GetAiProfileTool"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] } }, required: ["id"] }
        def execute(args) = success(AiProfileTool.find(args[:id]).as_json)
      end

      # Profile Skill assignments
      class ListAiProfileSkillsTool < Mcp::BaseTool
        def name = "list_ai_profile_skills"
        def description = "List AI profile-skill assignments"
        def aliases = ["ListAiProfileSkills"]
        def input_schema = { type: "object", properties: { ai_profile_id: { type: %w[string integer] }, skill_id: { type: %w[string integer] } } }
        def execute(args)
          scope = AiProfileSkill.all
          scope = scope.where(ai_profile_id: args[:ai_profile_id]) if args[:ai_profile_id].present?
          scope = scope.where(skill_id: args[:skill_id]) if args[:skill_id].present?
          success(scope.map(&:as_json))
        end
      end

      class GetAiProfileSkillTool < Mcp::BaseTool
        def name = "get_ai_profile_skill"
        def description = "Get a single AI profile-skill assignment"
        def aliases = ["GetAiProfileSkill"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] } }, required: ["id"] }
        def execute(args) = success(AiProfileSkill.find(args[:id]).as_json)
      end

      # Profile MCP assignments
      class ListAiProfileMcpsTool < Mcp::BaseTool
        def name = "list_ai_profile_mcps"
        def description = "List AI profile-MCP assignments"
        def aliases = ["ListAiProfileMcps"]
        def input_schema = { type: "object", properties: { ai_profile_id: { type: %w[string integer] }, mcp_id: { type: %w[string integer] } } }
        def execute(args)
          scope = AiProfileMcp.all
          scope = scope.where(ai_profile_id: args[:ai_profile_id]) if args[:ai_profile_id].present?
          scope = scope.where(mcp_id: args[:mcp_id]) if args[:mcp_id].present?
          success(scope.map(&:as_json))
        end
      end

      class GetAiProfileMcpTool < Mcp::BaseTool
        def name = "get_ai_profile_mcp"
        def description = "Get a single AI profile-MCP assignment"
        def aliases = ["GetAiProfileMcp"]
        def input_schema = { type: "object", properties: { id: { type: %w[string integer] } }, required: ["id"] }
        def execute(args) = success(AiProfileMcp.find(args[:id]).as_json)
      end
    end
  end
end
