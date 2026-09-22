require "test_helper"

class Users::AiAdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "admin can open ai admin page" do
    get user_company_ai_admin_url(user_id: "me")

    assert_response :ok
    assert_select "h1", text: "AI Config"
    assert_select "section[aria-label='Profile list']"
    assert_select "a.ai-admin-nav-card .bot-card-name", text: "General AI Settings"
    assert_select "a.ai-admin-nav-card .bot-card-name", text: "MCPs"
    assert_select "a.ai-admin-nav-card .bot-card-name", text: "Tools"
    assert_select "a.ai-admin-nav-card .bot-card-name", text: "Skills"
  end

  test "admin can open dedicated ai settings pages" do
    get user_company_ai_admin_general_settings_url(user_id: "me")
    assert_response :ok
    assert_select "h1", text: "General AI Settings"

    get user_company_ai_admin_mcps_page_url(user_id: "me")
    assert_response :ok
    assert_select "h1", text: "MCPs"

    mcp = Mcp::Server.create!(
      name: "mcp_page_#{SecureRandom.hex(3)}",
      transport: "http",
      url: "http://localhost:9100/mcp",
      authentication: "none",
      status: "active"
    )

    get user_company_ai_admin_new_mcp_url(user_id: "me")
    assert_response :ok
    assert_select "h1", text: "Add MCP"

    get user_company_ai_admin_edit_mcp_url(user_id: "me", id: mcp.id)
    assert_response :ok
    assert_select "h1", text: "Edit MCP"

    get user_company_ai_admin_tools_page_url(user_id: "me")
    assert_response :ok
    assert_select "h1", text: "Tools"

    get user_company_ai_admin_skills_page_url(user_id: "me")
    assert_response :ok
    assert_select "h1", text: "Skills"

    get user_company_ai_admin_new_profile_url(user_id: "me", return_to: user_company_ai_admin_path(user_id: "me"))
    assert_response :ok
    assert_select "h1", text: "New AI Profile"
  end

  test "non admin cannot open ai admin page" do
    sign_in :kevin

    get user_company_ai_admin_url(user_id: "me")

    assert_response :forbidden
  end

  test "creates ai setting" do
    assert_difference -> { AiSetting.count }, 1 do
      post user_company_ai_admin_ai_settings_url(user_id: "me"), params: {
        ai_setting: {
          label: "new_limit_#{SecureRandom.hex(4)}",
          setting_value: 9
        }
      }
    end

    assert_redirected_to user_company_ai_admin_general_settings_url(user_id: "me")
  end

  test "mcp full crud" do
    post user_company_ai_admin_mcps_url(user_id: "me"), params: {
      mcp: {
        name: "Test MCP #{SecureRandom.hex(3)}",
        transport: "http",
        url: "http://localhost:9000/mcp",
        authentication: "none",
        status: "active",
        bearer_token: ""
      }
    }

    assert_redirected_to user_company_ai_admin_mcps_page_url(user_id: "me")

    created = Mcp::Server.order(:id).last
    assert_not_nil created

    patch user_company_ai_admin_mcp_url(user_id: "me", id: created.id), params: {
      mcp: {
        name: created.name,
        transport: "http",
        url: "http://localhost:9001/mcp",
        authentication: "bearer",
        status: "active",
        bearer_token: "token-123"
      }
    }

    assert_redirected_to user_company_ai_admin_mcps_page_url(user_id: "me")

    assert_equal "http://localhost:9001/mcp", created.reload.url
    assert_equal "bearer", created.authentication

    assert_difference -> { Mcp::Server.count }, -1 do
      delete user_company_ai_admin_mcp_destroy_url(user_id: "me", id: created.id)
    end

    assert_redirected_to user_company_ai_admin_mcps_page_url(user_id: "me")
  end

  test "http mcp with bearer auth requires bearer token" do
    assert_no_difference -> { Mcp::Server.count } do
      post user_company_ai_admin_mcps_url(user_id: "me"), params: {
        mcp: {
          name: "Bearer MCP #{SecureRandom.hex(3)}",
          transport: "http",
          url: "http://localhost:9010/mcp",
          authentication: "bearer",
          status: "active",
          bearer_token: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", text: "Add MCP"
  end

  test "stdio mcp requires command and args and can be created" do
    assert_no_difference -> { Mcp::Server.count } do
      post user_company_ai_admin_mcps_url(user_id: "me"), params: {
        mcp: {
          name: "Stdio MCP Invalid #{SecureRandom.hex(3)}",
          transport: "stdio",
          status: "active",
          command: "",
          args: "",
          environment: "API_KEY=secret"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", text: "Add MCP"

    assert_difference -> { Mcp::Server.count }, 1 do
      post user_company_ai_admin_mcps_url(user_id: "me"), params: {
        mcp: {
          name: "Stdio MCP #{SecureRandom.hex(3)}",
          transport: "stdio",
          status: "active",
          command: "npx",
          args: "-y @modelcontextprotocol/server-foo",
          environment: "DEBUG=1"
        }
      }
    end

    created = Mcp::Server.order(:id).last
    assert_equal "stdio", created.transport
    assert_equal "npx", created.command
    assert_equal "-y @modelcontextprotocol/server-foo", created.args
    assert_redirected_to user_company_ai_admin_mcps_page_url(user_id: "me")
  end

  test "mcps page shows cards with edit links" do
    mcp = Mcp::Server.create!(
      name: "mcp_card_#{SecureRandom.hex(3)}",
      transport: "http",
      url: "http://localhost:9200/mcp",
      authentication: "none",
      status: "active"
    )

    get user_company_ai_admin_mcps_page_url(user_id: "me")

    assert_response :ok
    assert_select "[data-mcp-card-name='#{mcp.name}']"
    assert_select "[data-mcp-card-name='#{mcp.name}'] a[href='#{user_company_ai_admin_edit_mcp_path(user_id: "me", id: mcp.id)}']", text: "Edit"
  end

  test "mcp forms hide bearer token when authentication is none" do
    mcp = Mcp::Server.create!(
      name: "mcp_none_auth_#{SecureRandom.hex(3)}",
      transport: "http",
      url: "http://localhost:9300/mcp",
      authentication: "none",
      status: "active"
    )

    get user_company_ai_admin_new_mcp_url(user_id: "me")
    assert_response :ok
    assert_select "[data-mcp-form-target='bearerField'][hidden]"

    get user_company_ai_admin_edit_mcp_url(user_id: "me", id: mcp.id)
    assert_response :ok
    assert_select "[data-mcp-form-target='bearerField'][hidden]"
  end

  test "toggles tool" do
    tool = Tool.create!(name: "toggle-tool-#{SecureRandom.hex(4)}", active: true)

    patch user_company_ai_admin_tool_toggle_url(user_id: "me", id: tool.id), params: { active: "0" }

    assert_redirected_to user_company_ai_admin_tools_page_url(user_id: "me")
    assert_not tool.reload.active?
  end

  test "toggles skill default and emits learn event without mutating skills" do
    skill = Skill.create!(name: "skill-#{SecureRandom.hex(4)}", add_by_default: false)

    patch user_company_ai_admin_skill_toggle_default_url(user_id: "me", id: skill.id), params: {
      add_by_default: "1"
    }

    assert skill.reload.add_by_default?

    assert_no_difference -> { Skill.count } do
      assert_difference -> { OutputEvent.count }, 1 do
        post user_company_ai_admin_skill_learn_url(user_id: "me"), params: {
          learn: {
            source_kind: "url",
            source_reference: "https://example.com/spec",
            notes: "Use this for onboarding",
            skill_name: "Onboarding Skill",
            skill_category: "operations"
          }
        }
      end
    end

    event = OutputEvent.order(:id).last
    assert_equal "skill_learning_requested", event.event_type
    assert_equal "Skill", event.event_data["target_type"]
    assert_equal "skill_learning_request", event.event_data.dig("content_payload", "type")
    assert_equal "url", event.event_data.dig("content_payload", "source_kind")
  end

  test "create profile with bot enabled derives bot name and creates bot user" do
    profile_name = "delivery_ops_#{SecureRandom.hex(3)}"
    return_to = user_company_ai_admin_url(user_id: "me")

    assert_difference -> { AiProfile.count }, 1 do
      assert_difference -> { User.where(role: :bot).count }, 1 do
        post user_company_ai_admin_profiles_url(user_id: "me"), params: {
          return_to: return_to,
          ai_profile: profile_attributes(profile_name: profile_name, bot: "1", bot_name: "")
        }
      end
    end

    profile = AiProfile.order(:id).last
    assert_equal profile_name.tr("_-", " ").split.map(&:capitalize).join(" "), profile.bot_name

    bot_user = User.where(role: :bot, name: profile.bot_name).order(:id).last
    assert_not_nil bot_user
    assert bot_user.active?

    assert_redirected_to return_to
  end

  test "create profile respects bot editable and tool assignment toggles" do
    return_to = user_company_ai_admin_url(user_id: "me")

    post user_company_ai_admin_profiles_url(user_id: "me"), params: {
      return_to: return_to,
      ai_profile: profile_attributes(
        profile_name: "toggle_profile_#{SecureRandom.hex(3)}",
        bot: "0",
        editable: "0",
        tool_sets_editable: "0"
      )
    }

    assert_redirected_to return_to

    profile = AiProfile.order(:id).last
    assert_not profile.bot?
    assert_not profile.editable?
    assert_not profile.tool_sets_editable?
  end

  test "disabling profile bot deactivates matching bot user without deletion" do
    bot_name = "Sync Agent #{SecureRandom.hex(3)}"
    profile = AiProfile.create!(profile_attributes(profile_name: "sync_agent_#{SecureRandom.hex(3)}", bot: true, bot_name: bot_name))
    bot_user = User.create_bot!(name: bot_name, display_name: bot_name)

    assert_no_difference -> { User.where(role: :bot).count } do
      patch user_company_ai_admin_profile_update_url(user_id: "me", id: profile.id), params: {
        ai_profile: profile_attributes(
          profile_name: profile.profile_name,
          bot: "0",
          bot_name: bot_name,
          editable: "1",
          tool_sets_editable: "1"
        )
      }
    end

    assert_not profile.reload.bot?
    assert bot_user.reload.deactivated?
  end

  test "read-only profile cannot be updated or deleted" do
    profile = AiProfile.create!(profile_attributes(profile_name: "readonly_#{SecureRandom.hex(3)}", editable: false))

    patch user_company_ai_admin_profile_update_url(user_id: "me", id: profile.id), params: {
      ai_profile: profile_attributes(profile_name: "changed_name", editable: false)
    }

    assert_redirected_to user_company_ai_admin_profile_url(user_id: "me", id: profile.id, anchor: "profile-edit")
    assert_equal profile.profile_name, profile.reload.profile_name

    assert_no_difference -> { AiProfile.count } do
      delete user_company_ai_admin_profile_destroy_url(user_id: "me", id: profile.id)
    end
  end

  test "tool skill and mcp assignment updates are blocked when tool_sets_editable is false" do
    profile = AiProfile.create!(profile_attributes(profile_name: "locked_assignments_#{SecureRandom.hex(3)}", editable: true, tool_sets_editable: false))
    tool = Tool.create!(name: "tool-#{SecureRandom.hex(4)}", active: true)
    skill = Skill.create!(name: "skill-#{SecureRandom.hex(4)}")
    mcp = Mcp::Server.create!(
      name: "mcp-#{SecureRandom.hex(4)}",
      transport: "http",
      url: "http://localhost:7000/mcp",
      authentication: "none",
      status: "active"
    )

    assert_no_difference -> { AiProfileTool.count } do
      patch user_company_ai_admin_profile_tool_toggle_url(user_id: "me", profile_id: profile.id, tool_id: tool.id), params: { enabled: "1" }
    end

    assert_no_difference -> { AiProfileSkill.count } do
      patch user_company_ai_admin_profile_skill_toggle_url(user_id: "me", profile_id: profile.id, skill_id: skill.id), params: { enabled: "1" }
    end

    assert_no_difference -> { AiProfileMcp.count } do
      patch user_company_ai_admin_profile_mcp_toggle_url(user_id: "me", profile_id: profile.id, mcp_id: mcp.id), params: { active: "1" }
    end
  end

  test "main model and fallback model are not visible in ai admin forms" do
    profile = AiProfile.create!(profile_attributes(profile_name: "visibility_#{SecureRandom.hex(3)}"))

    get user_company_ai_admin_url(user_id: "me")
    assert_response :ok
    assert_no_match(/main_model/i, @response.body)
    assert_no_match(/fallback_model/i, @response.body)

    get user_company_ai_admin_profile_url(user_id: "me", id: profile.id)
    assert_response :ok
    assert_select "h1", text: "Edit Profile"
    assert_no_match(/General AI Settings/i, @response.body)
    assert_no_match(/main_model/i, @response.body)
    assert_no_match(/fallback_model/i, @response.body)

    get user_company_ai_admin_new_profile_url(user_id: "me", return_to: user_company_ai_admin_path(user_id: "me"))
    assert_response :ok
    assert_no_match(/main_model/i, @response.body)
    assert_no_match(/fallback_model/i, @response.body)
  end

  test "bot profile card shows robot emoji when related robot avatar is missing" do
    bot_name = "Card Bot #{SecureRandom.hex(3)}"
    profile = AiProfile.create!(profile_attributes(profile_name: "card_bot_profile_#{SecureRandom.hex(3)}", bot: true, bot_name: bot_name))
    User.create_bot!(name: bot_name, display_name: bot_name)

    get user_company_ai_admin_url(user_id: "me")

    assert_response :ok
    assert_select "[data-profile-card-name='#{profile.profile_name}'] .profile-list-card__emoji--bot", text: "🤖"
  end

  test "bot profile card shows related robot picture when avatar exists" do
    bot_name = "Avatar Bot #{SecureRandom.hex(3)}"
    profile = AiProfile.create!(profile_attributes(profile_name: "avatar_bot_profile_#{SecureRandom.hex(3)}", bot: true, bot_name: bot_name))
    bot_user = User.create_bot!(name: bot_name, display_name: bot_name)
    bot_user.update!(avatar: fixture_file_upload("moon.jpg", "image/jpeg"))

    get user_company_ai_admin_url(user_id: "me")

    assert_response :ok
    assert_select "[data-profile-card-name='#{profile.profile_name}'] img.profile-list-card__avatar"
    assert_select "[data-profile-card-name='#{profile.profile_name}'] .profile-list-card__emoji--bot", count: 0
  end

  test "profile cards are direct links without open button" do
    profile = AiProfile.create!(profile_attributes(profile_name: "linked_profile_#{SecureRandom.hex(3)}"))

    get user_company_ai_admin_url(user_id: "me")

    assert_response :ok
    assert_select "a.profile-list-card--link[data-profile-card-name='#{profile.profile_name}'][href='#{user_company_ai_admin_profile_path(user_id: "me", id: profile.id)}']"
    assert_select "[data-profile-card-name='#{profile.profile_name}'] .profile-list-card__actions", count: 0
  end

  private

  def profile_attributes(overrides = {})
    {
      profile_name: "profile_#{SecureRandom.hex(3)}",
      soul: "Profile soul",
      bot: "0",
      bot_name: "",
      editable: true,
      tool_sets_editable: true,
      max_line_sessions: 2,
      max_concurrent_sessions: 2,
      auto_decompose_per_tick: 2,
      max_in_progress_per_profile: 2
    }.merge(overrides)
  end
end
