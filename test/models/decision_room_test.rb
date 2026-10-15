require "test_helper"

class DecisionRoomTest < ActiveSupport::TestCase
  test "associates a room with a project adr from the same project" do
    project = Project.create!(path: "/tmp/decision-room-test-#{SecureRandom.uuid}", name: "Decision Room Test Project")
    room = project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    adr = project.adrs.create!(
      identifier: "ADR-001",
      title: "Use event-driven sourcing",
      status: "accepted",
      decision_date: Date.current,
      active: true,
      position: 1
    )

    relation = DecisionRoom.new(room: room, project_adr: adr)
    assert relation.valid?
    assert_equal adr, relation.project_adr
    assert_equal room, relation.room
  end

  test "rejects a room and adr from different projects" do
    first_project = Project.create!(path: "/tmp/decision-room-first-#{SecureRandom.uuid}", name: "First Project")
    second_project = Project.create!(path: "/tmp/decision-room-second-#{SecureRandom.uuid}", name: "Second Project")
    room = first_project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    adr = second_project.adrs.create!(
      identifier: "ADR-101",
      title: "Independent decision",
      status: "proposed",
      active: true,
      position: 1
    )

    relation = DecisionRoom.new(room: room, project_adr: adr)
    assert_not relation.valid?
    assert_includes relation.errors[:base], "must belong to the same project"
  end
end
