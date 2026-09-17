require "test_helper"

class Api::CompanyStatusItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @period = CompanyStatusPeriod.create!(slug: "september-2026", name: "September 2026", current: true, position: 1)
    @item = @period.company_status_items.create!(
      category: "priorities",
      title: "Launch MVP",
      subtitle: "Ship core workflow",
      description: "Priority item for launch",
      owner: "Product",
      target_date: "2026-09-10",
      status: "Open",
      impact: "High",
      percent: 40,
      color: "blue",
      evidence: "Validated",
      severity: "important",
      icon: "rocket",
      from_name: "PM",
      to_name: "Team",
      actions: [ "Approve" ]
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all company status items with a valid token" do
    second_item = @period.company_status_items.create!(category: "risks", title: "Risk item", description: "Need mitigation")

    get api_company_status_items_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @item.id, second_item.id ].sort, body["company_status_items"].map { |item| item["id"] }.sort
  end

  test "returns a single company status item with a valid token" do
    get api_company_status_item_url(@item.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @item.id, body["id"]
    assert_equal @item.title, body["title"]
  end

  test "returns company status items for a period with a valid token" do
    get by_period_api_company_status_items_url(company_status_period_id: @period.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal @item.id, body["company_status_items"].first["id"]
  end

  test "creates a company status item with a valid token" do
    assert_difference -> { CompanyStatusItem.count }, 1 do
      post api_company_status_items_url,
        params: {
          company_status_period_id: @period.id,
          category: "decisions",
          title: "Decision on release",
          description: "Need final sign-off",
          owner: "Engineering"
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Decision on release", body["title"]
    assert_equal "decisions", body["category"]
    assert_equal @period.id, body["company_status_period_id"]
  end

  test "updates a company status item with a valid token" do
    patch api_company_status_item_url(@item.id),
      params: {
        title: "Updated launch priority",
        owner: "Ops",
        status: "Closed"
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated launch priority", body["title"]
    assert_equal "Ops", body["owner"]
    assert_equal "Closed", body["status"]
  end

  test "deletes a company status item with a valid token" do
    assert_difference -> { CompanyStatusItem.count }, -1 do
      delete api_company_status_item_url(@item.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil CompanyStatusItem.find_by(id: @item.id)
  end

  test "returns advanced filtered company status items with optional filters and pagination" do
    second_item = @period.company_status_items.create!(category: "risks", title: "Risk item", severity: "critical")

    get advanced_filter_api_company_status_items_url(
      category: "risks",
      severity: "critical",
      company_status_period_id: @period.id,
      page: 1,
      per_page: 10
    ), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ second_item.id ], body["company_status_items"].map { |item| item["id"] }

    get advanced_filter_api_company_status_items_url, headers: { "Authorization" => "Bearer test-token" }
    assert_response :success
    assert_equal 2, JSON.parse(response.body)["count"]
  end

  test "rejects requests without a token" do
    get api_company_status_items_url
    assert_response :unauthorized
  end

  test "returns not found for missing company status item" do
    get api_company_status_item_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
