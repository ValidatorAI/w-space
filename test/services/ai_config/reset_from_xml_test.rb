require "test_helper"
require "tempfile"

class AiConfig::ResetFromXmlTest < ActiveSupport::TestCase
  test "exact mirror reset updates ai config entities and profile assignments" do
    stale_tool = Tool.create!(name: "stale_tool_#{SecureRandom.hex(3)}", active: true)
    stale_skill = Skill.create!(name: "stale_skill_#{SecureRandom.hex(3)}")
    stale_mcp = Mcp::Server.create!(
      name: "stale_mcp_#{SecureRandom.hex(3)}",
      transport: "http",
      url: "http://localhost:9901/mcp",
      authentication: "none",
      status: "active"
    )

    legacy_profile = AiProfile.create!(
      profile_name: "legacy_profile_#{SecureRandom.hex(3)}",
      soul: "legacy",
      bot: false,
      editable: true,
      tool_sets_editable: true
    )
    legacy_profile.ai_profile_tools.create!(tool: stale_tool, enabled: true)
    legacy_profile.ai_profile_skills.create!(skill: stale_skill, enabled: true)
    legacy_profile.ai_profile_mcps.create!(mcp: stale_mcp, active: true)

    legacy_bot_name = "Legacy Reset Bot #{SecureRandom.hex(3)}"
    legacy_bot_profile = AiProfile.create!(
      profile_name: "legacy_bot_profile_#{SecureRandom.hex(3)}",
      soul: "legacy bot",
      bot: true,
      bot_name: legacy_bot_name,
      editable: true,
      tool_sets_editable: true
    )
    legacy_bot_user = User.create_bot!(name: legacy_bot_name, display_name: legacy_bot_name)

    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ai_config>
        <tools>
          <tool name="terminal"><active>true</active></tool>
          <tool name="file"><active>true</active></tool>
        </tools>
        <skills>
          <skill name="plan">
            <category>software-development</category>
            <description>Plan work</description>
            <skill_text>Use a short plan</skill_text>
            <add_by_default>true</add_by_default>
          </skill>
        </skills>
        <mcps>
          <mcp name="memory">
            <transport>http</transport>
            <url>http://127.0.0.1:1933/mcp</url>
            <authentication>none</authentication>
            <status>active</status>
          </mcp>
        </mcps>
        <profiles>
          <profile name="config">
            <soul><![CDATA[Config soul text]]></soul>
            <bot>false</bot>
            <editable>true</editable>
            <tool_sets_editable>true</tool_sets_editable>
            <max_number_of_workers>5</max_number_of_workers>
            <max_spawn_depth>2</max_spawn_depth>
            <tools>
              <tool name="terminal" />
              <tool name="file" />
            </tools>
            <skills>
              <skill name="plan" />
            </skills>
            <mcps>
              <mcp name="memory" />
            </mcps>
          </profile>
          <profile name="assistant_bot">
            <soul><![CDATA[Bot soul text]]></soul>
            <bot>true</bot>
            <bot_name>Assistant Bot</bot_name>
            <editable>true</editable>
            <tool_sets_editable>true</tool_sets_editable>
            <max_number_of_workers>3</max_number_of_workers>
            <max_spawn_depth>1</max_spawn_depth>
            <tools>
              <tool name="terminal" />
            </tools>
            <skills>
              <skill name="plan" />
            </skills>
            <mcps>
              <mcp name="memory" />
            </mcps>
          </profile>
        </profiles>
      </ai_config>
    XML

    Tempfile.create(["ai_config", ".xml"]) do |file|
      file.write(xml)
      file.flush

      summary = AiConfig::ResetFromXml.call(source_path: file.path)

      assert_equal ["file", "terminal"], Tool.order(:name).pluck(:name)
      assert_equal ["plan"], Skill.order(:name).pluck(:name)
      assert_equal ["memory"], Mcp::Server.order(:name).pluck(:name)
      assert_equal ["assistant_bot", "config"], AiProfile.order(:profile_name).pluck(:profile_name)

      config_profile = AiProfile.find_by!(profile_name: "config")
      assistant_bot = AiProfile.find_by!(profile_name: "assistant_bot")

      assert_equal "Config soul text", config_profile.soul
      assert_equal 5, config_profile.max_number_of_workers
      assert_equal 2, config_profile.max_spawn_depth
      assert assistant_bot.bot?
      assert_equal "Assistant Bot", assistant_bot.bot_name

      assert_equal ["file", "terminal"], config_profile.tools.order(:name).pluck(:name)
      assert_equal ["plan"], config_profile.skills.order(:name).pluck(:name)
      assert_equal ["memory"], config_profile.mcps.order(:name).pluck(:name)

      assert_nil AiProfile.find_by(id: legacy_profile.id)
      assert_nil AiProfile.find_by(id: legacy_bot_profile.id)
      assert legacy_bot_user.reload.deactivated?

      assistant_bot_user = User.where(role: :bot, name: "Assistant Bot").order(:id).last
      assert_not_nil assistant_bot_user
      assert assistant_bot_user.active?

      assert_equal 1, summary.dig("tools", "deleted")
      assert_equal 1, summary.dig("skills", "deleted")
      assert_equal 1, summary.dig("mcps", "deleted")
      assert_equal true, summary.dig("ai_profiles", "created") >= 1
      assert_equal true, summary.dig("ai_profiles", "deleted") >= 2
    end
  end

  test "reset fails when profile references unknown tool" do
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ai_config>
        <tools>
          <tool name="terminal"><active>true</active></tool>
        </tools>
        <skills>
          <skill name="plan"><add_by_default>true</add_by_default></skill>
        </skills>
        <mcps>
          <mcp name="memory"><transport>http</transport><url>http://127.0.0.1:1933/mcp</url><authentication>none</authentication><status>active</status></mcp>
        </mcps>
        <profiles>
          <profile name="config">
            <tools><tool name="missing_tool" /></tools>
            <skills><skill name="plan" /></skills>
            <mcps><mcp name="memory" /></mcps>
          </profile>
        </profiles>
      </ai_config>
    XML

    Tempfile.create(["ai_config_invalid", ".xml"]) do |file|
      file.write(xml)
      file.flush

      assert_raises(AiConfig::XmlLoader::ConfigError) do
        AiConfig::ResetFromXml.call(source_path: file.path)
      end
    end
  end
end
