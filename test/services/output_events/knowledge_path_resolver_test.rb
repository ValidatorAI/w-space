require "test_helper"

class OutputEvents::KnowledgePathResolverTest < ActiveSupport::TestCase
  test "returns project knowledge root path when project context is available" do
    project = Project.create!(name: "Resolver Project", path: "/tmp/knowledge-resolver-project-#{SecureRandom.hex(6)}")

    knowledge_path = OutputEvents::KnowledgePathResolver.resolve(
      event_type: "project_updated",
      event_id: project.id,
      target_type: "Project",
      data: {}
    )

    assert_equal(
      "<knowledge_path>\n- /company/#{Account.first.id}/projects/#{project.id}/knowledge\n</knowledge_path>",
      knowledge_path
    )
  end

  test "returns adr knowledge path when adr id is present" do
    project = Project.create!(name: "Resolver ADR Project", path: "/tmp/knowledge-resolver-adr-#{SecureRandom.hex(6)}")
    adr = project.adrs.create!(
      identifier: "ADR-#{SecureRandom.hex(4).upcase}",
      title: "Decision",
      status: "accepted",
      decision_date: Date.current
    )

    knowledge_path = OutputEvents::KnowledgePathResolver.resolve(
      event_type: "decision_approved",
      event_id: 100,
      target_type: "ApprovalRequest",
      data: { "adr_id" => adr.id }
    )

    assert_equal(
      "<knowledge_path>\n- /company/#{Account.first.id}/projects/#{project.id}/knowledge/adrs/#{adr.id}\n</knowledge_path>",
      knowledge_path
    )
  end

  test "returns nil when project context is unavailable" do
    knowledge_path = OutputEvents::KnowledgePathResolver.resolve(
      event_type: "user_banned",
      event_id: 1,
      target_type: "User",
      data: {}
    )

    assert_nil knowledge_path
  end
end
