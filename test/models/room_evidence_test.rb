require "test_helper"

class RoomEvidenceTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Evidence Project", path: "/tmp/evidence-project-#{SecureRandom.hex(4)}")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "Evidence Room", creator: users(:david))
  end

  test "links a canonical project asset to a room with room-specific summary" do
    asset = @project.external_assets.create!(
      title: "Launch brief",
      source_type: "external_url",
      url: "https://example.com/brief",
      meta_text: "Q3 review"
    )

    evidence = RoomEvidence.create!(room: @room, project_external_asset: asset, summary: "Relevant to this room decision")

    assert_equal "external_asset", evidence.evidence_type
    assert_equal asset, evidence.entity
    assert_equal "Relevant to this room decision", evidence.display_summary
    assert_equal "Launch brief", evidence.entity_title
  end

  test "rejects evidence that links an asset from a different project" do
    other_project = Project.create!(name: "Other Project", path: "/tmp/other-project-#{SecureRandom.hex(4)}")
    other_room = other_project.rooms.create!(type: "Rooms::Project", name: "Other Room", creator: users(:david))
    asset = @project.external_assets.create!(
      title: "Launch brief",
      source_type: "external_url",
      url: "https://example.com/brief",
      meta_text: "Q3 review"
    )

    evidence = RoomEvidence.new(room: other_room, project_external_asset: asset, summary: "Wrong project")

    assert_not evidence.valid?
    assert_includes evidence.errors[:base], "must belong to the same project as the room"
  end
end
