require "test_helper"

class DecisionRoomEconomicsTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Economics Project", path: "/tmp/economics-project-#{SecureRandom.hex(4)}")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "Economics Room", creator: users(:david))
    @adr = @project.adrs.create!(identifier: "ADR-ECON-001", title: "Use a guided build", decision_date: Date.current, status: "accepted")
    @decision_room = DecisionRoom.create!(room: @room, project_adr: @adr)
  end

  test "stores the room-scoped cost and risk framing for a canonical project decision" do
    economics = DecisionRoomEconomics.create!(
      decision_room: @decision_room,
      research_effort: 3,
      guided_build_effort: 1,
      expected_learning_value: 8,
      risk_level: "medium",
      risk_note: "Shallow validation risk remains if the user flow is wrong."
    )

    assert_equal @decision_room, economics.decision_room
    assert_equal 3, economics.research_effort
    assert_equal "medium", economics.risk_level
    assert_equal "Medium risk", economics.risk_label
  end
end
