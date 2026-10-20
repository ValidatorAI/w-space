require "test_helper"

class ProjectKnowledgeItemTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", path: "/tmp/test-project-#{SecureRandom.hex(4)}")
  end

  test "validations" do
    item = @project.knowledge_items.build
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
    assert_includes item.errors[:description], "can't be blank"

    item.title = "Infrastructure Routing"
    item.description = "Our VPS is hosted on Infomaniak."
    item.badge = "Architecture"
    assert item.valid?
  end

  test "for_badge and ordered scopes" do
    arch_item = @project.knowledge_items.create!(title: "Infra", description: "Infra desc", badge: "Architecture", position: 1)
    ai_item = @project.knowledge_items.create!(title: "Agents", description: "Agent desc", badge: "AI Integration", position: 2)

    assert_includes @project.knowledge_items.for_badge("Architecture"), arch_item
    assert_not_includes @project.knowledge_items.for_badge("Architecture"), ai_item
    assert_equal [ arch_item, ai_item ], @project.knowledge_items.ordered.to_a
  end

  test "exposes readable metadata and summaries" do
    item = @project.knowledge_items.create!(title: "Launch checklist", description: "Review rollout readiness and customer comms", badge: "Operations", position: 1)

    assert_equal "Operations", item.display_badge
    assert_equal "Review rollout readiness and customer comms", item.summary_text
  end
end
