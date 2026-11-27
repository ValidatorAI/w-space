require "test_helper"

class Api::UsersMembershipDirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-membership-directs-test", name: "Api Membership Directs Test")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "lists active users without bots by default" do
    get api_users_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body.map { |u| u["id"] }, users(:david).id
    assert_not_includes body.map { |u| u["id"] }, users(:bender).id
  end

  test "creates a user and allows activation" do
    post api_users_url,
         params: { user: { name: "New Person", email_address: "newperson@example.com", password: "secret123456", role: "member" } },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New Person", body["name"]

    patch activate_api_user_url(body["id"]), headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
  end

  test "lists room members and adds a user idempotently" do
    @room.memberships.grant_to(users(:jason))

    get api_room_members_url(@room.id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :success

    post api_room_members_url(@room.id),
         params: { user_id: users(:jason).id },
         headers: { "Authorization" => "Bearer test-token" }
    assert_response :success

    post api_room_members_url(@room.id),
         params: { user_id: users(:jason).id },
         headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
  end

  test "creates a direct room once for the same user set" do
    post api_directs_url,
         params: { user_ids: [ users(:jason).id ] },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    first = JSON.parse(response.body)

    post api_directs_url,
         params: { user_ids: [ users(:jason).id ] },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    second = JSON.parse(response.body)
    assert_equal first["room"]["id"], second["room"]["id"]
    assert_equal false, second["created"]
  end
end
