require "test_helper"

class CompanyStatusItemTest < ActiveSupport::TestCase
  setup do
    @period = CompanyStatusPeriod.create!(slug: "period-sample", name: "Sample Period")
  end

  test "validates category inclusion" do
    item = @period.company_status_items.build(category: "invalid_category", title: "Some title")
    assert_not item.valid?

    item.category = "priorities"
    assert item.valid?
  end

  test "formats as_status_payload with detail context" do
    item = @period.company_status_items.create!(
      category: "progress",
      title: "Core UI",
      percent: 85,
      color: "#10b981",
      evidence: "Passing CI",
      description: "Reagent components",
      owner: "Frontend Lead",
      target_date: "Aug 25, 2026",
      status_label: "85% Complete",
      impact: "Accelerates velocity",
      actions: [ "Mobile polish" ]
    )

    payload = item.as_status_payload

    assert_equal "Core UI", payload[:title]
    assert_equal "Core UI", payload[:label]
    assert_equal "85", payload[:percent]
    assert_equal "#10b981", payload[:color]
    assert_equal "Passing CI", payload[:evidence]
    assert_equal "Progress", payload[:details][:category]
    assert_equal "Frontend Lead", payload[:details][:owner]
    assert_equal "85% Complete", payload[:details][:status]
    assert_equal [ "Mobile polish" ], payload[:details][:actions]
  end

  test "builds category-based action event names and records them" do
    item = @period.company_status_items.create!(
      category: "risks",
      title: "Data migration risk",
      status: "Open",
      evidence: "Needs mitigation"
    )

    assert_equal "risk_approved", item.action_event_type(action: "approve")
    assert_equal "risk_denied", item.action_event_type(action: "deny")

    assert_difference -> { OutputEvent.count }, +1 do
      item.record_action_event!(actor: users(:david), action: "approve", status: "approved")
    end

    event = OutputEvent.order(:id).last
    assert_equal "risk_approved", event.event_type
    assert_equal item.id, event.event_id
    assert_equal "CompanyStatusItem", event.event_data["target_type"]
    assert_equal "risks", event.event_data["category"]
    assert_equal "approved", event.event_data["status"]
    assert_equal "Data migration risk", event.event_data["content"]
  end
end
