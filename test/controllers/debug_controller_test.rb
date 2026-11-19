require "test_helper"

class DebugControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_admin_debug = ENV["ADMIN_DEBUG"]
    @previous_admin_debug_lower = ENV["admin_debug"]
    ENV["ADMIN_DEBUG"] = "true"
    ENV.delete("admin_debug")
  end

  teardown do
    ENV["ADMIN_DEBUG"] = @previous_admin_debug
    ENV["admin_debug"] = @previous_admin_debug_lower
  end

  test "admin can access debug page when flag is enabled" do
    sign_in :david

    get "/debug"

    assert_response :ok
    assert_select "h1", "Debug"
  end

  test "non-admin cannot access debug page when flag is enabled" do
    sign_in :kevin

    get "/debug"

    assert_response :forbidden
  end

  test "debug page is not found when flag is disabled" do
    sign_in :david

    ENV["ADMIN_DEBUG"] = "false"

    get "/debug"

    assert_response :not_found
  end
end
