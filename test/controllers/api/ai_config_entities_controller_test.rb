require "test_helper"

class Api::AiConfigEntitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"

    @ai_profile = AiProfile.create!(
      profile_name: "api_profile_#{SecureRandom.hex(3)}",
      soul: "private soul text",
      bot: false,
      editable: true,
      tool_sets_editable: true
    )

    @ai_setting = AiSetting.create!(label: "max_retries_#{SecureRandom.hex(2)}", setting_value: 5)

    @mcp = Mcp::Server.create!(
      name: "api_mcp_#{SecureRandom.hex(3)}",
      transport: "http",
      url: "http://localhost:9500/mcp",
      authentication: "bearer",
      bearer_token: "super-secret-token",
      status: "active"
    )

    @tool = Tool.create!(name: "api_tool_#{SecureRandom.hex(3)}", active: true)

    @skill = Skill.create!(
      name: "api_skill_#{SecureRandom.hex(3)}",
      category: "operations",
      description: "Skill description",
      skill_text: "internal prompt text",
      add_by_default: true
    )

    @ai_profile_tool = AiProfileTool.create!(ai_profile: @ai_profile, tool: @tool, enabled: true)
    @ai_profile_skill = AiProfileSkill.create!(ai_profile: @ai_profile, skill: @skill, enabled: false)
    @ai_profile_mcp = AiProfileMcp.create!(ai_profile: @ai_profile, mcp: @mcp, active: true)
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "rejects ai config api requests without token" do
    get api_ai_profiles_url
    assert_response :unauthorized
  end

  test "returns all ai config entity indexes with valid token" do
    get api_ai_profiles_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["ai_profiles"].map { |row| row["id"] }, @ai_profile.id

    get api_ai_settings_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["ai_settings"].map { |row| row["id"] }, @ai_setting.id

    get api_mcps_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["mcps"].map { |row| row["id"] }, @mcp.id

    get api_tools_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["tools"].map { |row| row["id"] }, @tool.id

    get api_skills_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["skills"].map { |row| row["id"] }, @skill.id

    get api_ai_profile_tools_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["ai_profile_tools"].map { |row| row["id"] }, @ai_profile_tool.id

    get api_ai_profile_skills_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["ai_profile_skills"].map { |row| row["id"] }, @ai_profile_skill.id

    get api_ai_profile_mcps_url, headers: auth_headers
    assert_response :success
    assert_includes JSON.parse(response.body)["ai_profile_mcps"].map { |row| row["id"] }, @ai_profile_mcp.id
  end

  test "returns all ai config entity show endpoints with valid token" do
    get api_ai_profile_url(@ai_profile), headers: auth_headers
    assert_response :success
    assert_equal @ai_profile.id, JSON.parse(response.body)["id"]

    get api_ai_setting_url(@ai_setting), headers: auth_headers
    assert_response :success
    assert_equal @ai_setting.id, JSON.parse(response.body)["id"]

    get api_mcp_url(@mcp), headers: auth_headers
    assert_response :success
    assert_equal @mcp.id, JSON.parse(response.body)["id"]

    get api_tool_url(@tool), headers: auth_headers
    assert_response :success
    assert_equal @tool.id, JSON.parse(response.body)["id"]

    get api_skill_url(@skill), headers: auth_headers
    assert_response :success
    assert_equal @skill.id, JSON.parse(response.body)["id"]

    get api_ai_profile_tool_url(@ai_profile_tool), headers: auth_headers
    assert_response :success
    assert_equal @ai_profile_tool.id, JSON.parse(response.body)["id"]

    get api_ai_profile_skill_url(@ai_profile_skill), headers: auth_headers
    assert_response :success
    assert_equal @ai_profile_skill.id, JSON.parse(response.body)["id"]

    get api_ai_profile_mcp_url(@ai_profile_mcp), headers: auth_headers
    assert_response :success
    assert_equal @ai_profile_mcp.id, JSON.parse(response.body)["id"]
  end

  test "returns not found for missing ai config entities" do
    get api_ai_profile_url(-1), headers: auth_headers
    assert_response :not_found

    get api_ai_setting_url(-1), headers: auth_headers
    assert_response :not_found

    get api_mcp_url(-1), headers: auth_headers
    assert_response :not_found

    get api_tool_url(-1), headers: auth_headers
    assert_response :not_found

    get api_skill_url(-1), headers: auth_headers
    assert_response :not_found

    get api_ai_profile_tool_url(-1), headers: auth_headers
    assert_response :not_found

    get api_ai_profile_skill_url(-1), headers: auth_headers
    assert_response :not_found

    get api_ai_profile_mcp_url(-1), headers: auth_headers
    assert_response :not_found
  end

  test "redacts sensitive ai config fields" do
    get api_ai_profile_url(@ai_profile), headers: auth_headers
    assert_response :success
    profile_payload = JSON.parse(response.body)
    assert_equal true, profile_payload["soul_present"]
    assert_not profile_payload.key?("soul")

    get api_mcp_url(@mcp), headers: auth_headers
    assert_response :success
    mcp_payload = JSON.parse(response.body)
    assert_equal true, mcp_payload["bearer_token_present"]
    assert_not mcp_payload.key?("bearer_token")

    get api_skill_url(@skill), headers: auth_headers
    assert_response :success
    skill_payload = JSON.parse(response.body)
    assert_equal true, skill_payload["skill_text_present"]
    assert_not skill_payload.key?("skill_text")
  end

  test "filters assignment indexes by parent relation" do
    second_profile = AiProfile.create!(profile_name: "api_profile_#{SecureRandom.hex(3)}")

    second_profile_tool = AiProfileTool.create!(
      ai_profile: second_profile,
      tool: Tool.create!(name: "api_tool_#{SecureRandom.hex(3)}"),
      enabled: false
    )
    second_profile_skill = AiProfileSkill.create!(
      ai_profile: second_profile,
      skill: Skill.create!(name: "api_skill_#{SecureRandom.hex(3)}"),
      enabled: true
    )
    second_profile_mcp = AiProfileMcp.create!(
      ai_profile: second_profile,
      mcp: Mcp::Server.create!(
        name: "api_mcp_#{SecureRandom.hex(3)}",
        transport: "http",
        url: "http://localhost:9600/mcp",
        authentication: "none",
        status: "active"
      ),
      active: false
    )

    get api_ai_profile_tools_url(ai_profile_id: @ai_profile.id), headers: auth_headers
    assert_response :success
    tool_ids = JSON.parse(response.body)["ai_profile_tools"].map { |row| row["id"] }
    assert_includes tool_ids, @ai_profile_tool.id
    assert_not_includes tool_ids, second_profile_tool.id

    get api_ai_profile_skills_url(ai_profile_id: @ai_profile.id), headers: auth_headers
    assert_response :success
    skill_ids = JSON.parse(response.body)["ai_profile_skills"].map { |row| row["id"] }
    assert_includes skill_ids, @ai_profile_skill.id
    assert_not_includes skill_ids, second_profile_skill.id

    get api_ai_profile_mcps_url(ai_profile_id: @ai_profile.id), headers: auth_headers
    assert_response :success
    mcp_ids = JSON.parse(response.body)["ai_profile_mcps"].map { |row| row["id"] }
    assert_includes mcp_ids, @ai_profile_mcp.id
    assert_not_includes mcp_ids, second_profile_mcp.id
  end

  test "creates, updates, and deletes ai profiles through the mutation api" do
    post api_ai_profiles_url, params: {
      ai_profile: {
        profile_name: "api_mutation_profile_#{SecureRandom.hex(3)}",
        soul: "inline profile soul",
        bot: "1",
        bot_name: "",
        editable: "1",
        tool_sets_editable: "1",
        max_number_of_workers: 4,
        max_spawn_depth: 2
      }
    }, headers: auth_headers

    assert_response :created
    payload = JSON.parse(response.body)
    assert_equal true, payload["bot"]
    assert_match(/\Aapi_mutation_profile_/, payload["profile_name"])
    profile = AiProfile.order(:id).last
    assert_not_nil profile

    patch api_ai_profile_url(profile), params: {
      ai_profile: {
        profile_name: "updated_profile_#{SecureRandom.hex(3)}",
        bot: "0",
        bot_name: "",
        editable: "1",
        tool_sets_editable: "1",
        max_number_of_workers: 5,
        max_spawn_depth: 3
      }
    }, headers: auth_headers

    assert_response :success
    assert_match(/\Aupdated_profile_/, profile.reload.profile_name)

    delete api_ai_profile_url(profile), headers: auth_headers
    assert_response :no_content
    assert_nil AiProfile.find_by(id: profile.id)
  end

  test "toggles ai profile tool assignment with the api" do
    tool = Tool.create!(name: "api_toggle_tool_#{SecureRandom.hex(3)}", active: true)

    patch api_toggle_ai_profile_tool_path(profile_id: @ai_profile.id, tool_id: tool.id), params: { enabled: "1" }, headers: auth_headers
    assert_response :success
    assert_equal true, @ai_profile.reload.ai_profile_tools.find_by(tool: tool).enabled

    patch api_toggle_ai_profile_tool_path(profile_id: @ai_profile.id, tool_id: tool.id), params: { enabled: "0" }, headers: auth_headers
    assert_response :success
    assert_equal false, @ai_profile.reload.ai_profile_tools.find_by(tool: tool).enabled
  end

  private

  def auth_headers(token = "test-token")
    { "Authorization" => "Bearer #{token}" }
  end
end
