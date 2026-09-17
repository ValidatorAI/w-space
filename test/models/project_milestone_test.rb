require "test_helper"

class ProjectMilestoneTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", path: "/tmp/test-project-#{SecureRandom.hex(4)}")
  end

  test "validations" do
    milestone = @project.project_milestones.build
    assert_not milestone.valid?
    assert_includes milestone.errors[:title], "can't be blank"

    milestone.title = "Discovery & framework alignment"
    assert milestone.valid?
  end

  test "active and ordering scopes" do
    archived_milestone = @project.project_milestones.create!(title: "Legacy milestone", description: "Old state", position: 1, active: false)
    active_milestone = @project.project_milestones.create!(title: "Baseline setup", description: "Initial workspace configured", position: 2, active: true)

    assert_includes @project.project_milestones.active, active_milestone
    assert_not_includes @project.project_milestones.active, archived_milestone
    assert_equal [archived_milestone, active_milestone], @project.project_milestones.ordered.to_a
  end
end
