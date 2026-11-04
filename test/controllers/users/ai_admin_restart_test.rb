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

  test "restarts hermes via the CLI" do
    Users::AiAdminController.any_instance.expects(:system).with("hermes gateway restart").returns(true)

    post user_company_ai_admin_restart_w_bridge_url(user_id: "me")

    assert_response :redirect
    assert_redirected_to user_company_ai_admin_url(user_id: "me")
    assert_equal "Hermes gateway restart triggered", flash[:notice]
  end
end
