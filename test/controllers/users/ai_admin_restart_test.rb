require "test_helper"

class AiAdminRestartTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @admin = User.create!(
      name: "david",
      display_name: "David Heinemeier",
      email_address: "david@example.com",
      role: :administrator,
      password: "secret123456"
    )
    sign_in @admin
  end

  test "restarts via file trigger path when output events url is blank" do
    previous_url = ENV["OUTPUT_EVENTS_URL"]
    previous_trigger = ENV["RESTART_TRIGGER_PATH"]
    test_trigger_file = Rails.root.join("tmp/test_restart_trigger.txt")
    FileUtils.rm_f(test_trigger_file)

    ENV["OUTPUT_EVENTS_URL"] = ""
    ENV["RESTART_TRIGGER_PATH"] = test_trigger_file.to_s
    Hermes.reset_configuration!

    post user_company_ai_admin_restart_w_bridge_url(user_id: "me")

    assert_response :redirect
    assert_redirected_to user_company_ai_admin_url(user_id: "me")
    assert_equal "W-Bridge restart triggered", flash[:notice]
    assert File.exist?(test_trigger_file)
  ensure
    FileUtils.rm_f(test_trigger_file)
    ENV["OUTPUT_EVENTS_URL"] = previous_url
    ENV["RESTART_TRIGGER_PATH"] = previous_trigger
    Hermes.reset_configuration!
  end

  test "restarts via HTTP when output events url is configured" do
    previous_url = ENV["OUTPUT_EVENTS_URL"]
    previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_URL"] = "http://localhost:8031/space_events"
    ENV["OUTPUT_EVENTS_TOKEN"] = "token-secret"

    stub_request(:post, "http://localhost:8031/restart")
      .with(headers: { "Authorization" => "Bearer token-secret" })
      .to_return(status: 200, body: { status: "ok" }.to_json, headers: { "Content-Type" => "application/json" })

    post user_company_ai_admin_restart_w_bridge_url(user_id: "me")

    assert_response :redirect
    assert_redirected_to user_company_ai_admin_url(user_id: "me")
    assert_equal "W-Bridge restart triggered", flash[:notice]
    assert_requested :post, "http://localhost:8031/restart"
  ensure
    ENV["OUTPUT_EVENTS_URL"] = previous_url
    ENV["OUTPUT_EVENTS_TOKEN"] = previous_token
  end
end
