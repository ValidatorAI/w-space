require "test_helper"

class RoomContextToolsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @account = Account.first || Account.create!(name: "Test Acc")
    @user = User.create!(name: "alice", display_name: "Alice", email_address: "alice@example.com", role: :member)
    @project = Project.create!(name: "Room MCP Project", path: "/tmp/room-mcp-project", slug: "room-mcp-project")
    @room = Rooms::Open.create!(name: "Design Room", creator: @user, project: @project)

    @adr = @project.adrs.create!(identifier: "ADR-001", title: "Adopt the room-first decision flow", status: "accepted", decision_date: Date.current)
    @decision_room = @room.decision_rooms.create!(project_adr: @adr)
    @asset = @project.external_assets.create!(title: "Research brief", url: "https://example.com/research", source_type: "external_url", active: true)
    @room.room_evidences.create!(project_external_asset: @asset, summary: "Important evidence for this room", author_name: "Alice", visibility: "project")
    @economics = DecisionRoomEconomics.create!(
      decision_room: @decision_room,
      risk_level: "medium",
      research_effort: 2,
      guided_build_effort: 5,
      expected_learning_value: 8
    )
  end

  test "room decision context tool exposes room-linked ADR metadata" do
    tool = Mcp::Registry.find_tool("room_decision_context", scope: :read)
    refute_nil tool

    result = tool.call(room_id: @room.id)
    assert_equal false, result[:isError]

    payload = JSON.parse(result[:content].first[:text])
    assert_equal @room.id, payload["room_id"]
    assert_equal "Design Room", payload["room_name"]
    assert_equal 1, payload["decisions"].size
    assert_equal "ADR-001", payload["decisions"].first["identifier"]
    assert_equal "accepted", payload["decisions"].first["status"]
  end

  test "room evidence tool exposes source provenance and freshness metadata" do
    tool = Mcp::Registry.find_tool("room_evidence", scope: :read)
    refute_nil tool

    result = tool.call(room_id: @room.id)
    assert_equal false, result[:isError]

    payload = JSON.parse(result[:content].first[:text])
    assert_equal @room.id, payload["room_id"]
    assert_equal 1, payload["evidence"].size
    assert_equal "Research brief", payload["evidence"].first["entity_title"]
    assert_equal "Important evidence for this room", payload["evidence"].first["summary"]
    assert_equal "Alice", payload["evidence"].first["author_name"]
  end

  test "room economics tool exposes risk and effort framing" do
    tool = Mcp::Registry.find_tool("room_economics", scope: :read)
    refute_nil tool

    result = tool.call(room_id: @room.id)
    assert_equal false, result[:isError]

    payload = JSON.parse(result[:content].first[:text])
    assert_equal @room.id, payload["room_id"]
    assert_equal "medium", payload["risk_level"]
    assert_equal 2, payload["research_effort"]
    assert_equal 5, payload["guided_build_effort"]
    assert_equal 8, payload["expected_learning_value"]
  end
end
