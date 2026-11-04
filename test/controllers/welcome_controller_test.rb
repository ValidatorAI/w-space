require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "redirects to the first created visible room the user has access to" do
    get root_url

    assert_redirected_to room_url(users(:david).rooms.original)
  end

  test "redirects to the last room visited, if we have one" do
    cookies[:last_room] = rooms(:watercooler).id

    get root_url

    assert_redirected_to room_url(rooms(:watercooler))
  end

  test "redirects to company home when user has no room or project" do
    user = users(:david)
    user.memberships.delete_all
    user.project_users.delete_all

    get root_url

    assert_redirected_to user_company_home_path(user_id: "me")
  end
end
