require "test_helper"

class CompanyStatusPeriodTest < ActiveSupport::TestCase
  test "validates presence of slug and name" do
    period = CompanyStatusPeriod.new
    assert_not period.valid?

    period.slug = "september-2026"
    period.name = "September 2026"
    assert period.valid?
  end

  test "validates uniqueness of slug" do
    CompanyStatusPeriod.create!(slug: "unique-period", name: "Period 1")
    duplicate = CompanyStatusPeriod.new(slug: "unique-period", name: "Period 2")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "orders pending decisions first and labels room decisions" do
    period = CompanyStatusPeriod.create!(slug: "room-decisions", name: "Room Decisions", current: true)

    period.company_status_items.create!(
      category: "decisions",
      title: "Approved launch decision",
      subtitle: "Launch approved",
      status: "approved",
      detail_category: "Room: Alpha",
      position: 2,
      description: "Already settled"
    )
    period.company_status_items.create!(
      category: "decisions",
      title: "Need room signoff",
      subtitle: "Waiting for room decision",
      status: "pending",
      detail_category: "Room: Beta",
      position: 1,
      description: "Open decision"
    )

    payload = period.as_status_payload
    assert_equal ["Need room signoff", "Approved launch decision"], payload[:decisions].map { |item| item[:title] }
    assert_equal ["Room: Beta", "Room: Alpha"], payload[:decisions].map { |item| item[:details][:room_label] }
  end

  test "as_status_payload returns categorized items" do
    period = CompanyStatusPeriod.create!(slug: "test-period", name: "Test Period", current: true)
    period.company_status_items.create!(
      category: "priorities",
      title: "Priority Item 1",
      subtitle: "Launch MVP",
      description: "Priority details",
      owner: "Dev Lead"
    )
    period.company_status_items.create!(
      category: "risks",
      title: "Risk Item 1",
      severity: "danger",
      description: "Critical risk"
    )

    payload = period.as_status_payload

    assert_equal 1, payload[:priorities].length
    assert_equal "Priority Item 1", payload[:priorities].first[:title]
    assert_equal "Launch MVP", payload[:priorities].first[:outcome]
    assert_equal "Dev Lead", payload[:priorities].first[:details][:owner]

    assert_equal 1, payload[:risks].length
    assert_equal "Risk Item 1", payload[:risks].first[:title]
    assert_equal "danger", payload[:risks].first[:type]
  end
end
