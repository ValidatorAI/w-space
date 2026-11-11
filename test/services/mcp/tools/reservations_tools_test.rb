require "test_helper"

class ReservationsToolsTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(path: "/tmp/mcp-file-reservations-test", name: "MCP Reservation Test")
    @holder = User.create!(name: "David", display_name: "David", email_address: "david@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
    @other = User.create!(name: "Jason", display_name: "Jason", email_address: "jason@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
    Mcp::Registry.reset!
    Mcp.load_tools!
  end

  test "check_file_conflicts is available in read scope and returns empty list when clean" do
    tool = Mcp::Registry.find_tool("check_file_conflicts", scope: :read)
    assert_not_nil tool
    assert_nil Mcp::Registry.find_tool("reserve_file", scope: :read)

    payload = tool.call(project_id: @project.id, patterns: ["app/models/*.rb"])
    body = JSON.parse(payload[:content].first[:text])
    assert_equal false, payload[:isError]
    assert_equal [], body["conflicts"]
  end

  test "reserve_file detects conflicts between users and enforces action scope" do
    @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.hour.from_now
    )

    tool = Mcp::Registry.find_tool("reserve_file", scope: :action)
    assert_not_nil tool

    payload = tool.call(
      project_id: @project.id,
      patterns: ["app/models/user.rb"],
      user_name: @other.name,
      reason: "Competing edit"
    )

    assert_equal true, payload[:isError]
    assert_includes payload[:content].first[:text], "conflict"
    assert_includes payload[:content].first[:text], @holder.name
  end

  test "renew_file_reservation enforces holder ownership and release_file_reservation is idempotent" do
    reservation = @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.minute.from_now
    )

    renew_tool = Mcp::Registry.find_tool("renew_file_reservation", scope: :action)
    release_tool = Mcp::Registry.find_tool("release_file_reservation", scope: :action)

    payload = renew_tool.call(reservation_id: reservation.id, user_name: @other.name)
    assert_equal true, payload[:isError]
    assert_includes payload[:content].first[:text], "not holder"

    success = renew_tool.call(reservation_id: reservation.id, user_name: @holder.name, ttl_seconds: 900)
    assert_equal false, success[:isError]

    release_payload = release_tool.call(reservation_id: reservation.id, user_name: @holder.name)
    assert_equal false, release_payload[:isError]
    payload = JSON.parse(release_payload[:content].first[:text])
    assert_equal "released", payload["status"]
    assert_equal reservation.id, payload["reservation_id"]
  end
end
