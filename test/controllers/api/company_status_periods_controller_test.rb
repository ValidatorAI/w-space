require "test_helper"

class Api::CompanyStatusPeriodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @period = CompanyStatusPeriod.create!(slug: "september-2026", name: "September 2026", current: true, position: 1)
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all company status periods with a valid token" do
    get api_company_status_periods_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal @period.id, body["company_status_periods"].first["id"]
  end

  test "returns a single company status period by id with a valid token" do
    get api_company_status_period_url(@period.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @period.id, body["id"]
    assert_equal @period.slug, body["slug"]
  end

  test "returns a single company status period by slug with a valid token" do
    get "/api/company_status_periods/by_slug/#{@period.slug}", headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @period.slug, body["slug"]
  end

  test "returns current company status period with a valid token" do
    get current_api_company_status_periods_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @period.id, body["id"]
    assert_equal true, body["current"]
  end

  test "returns current company status period by name with a valid token" do
    get "/api/company_status_periods/by_name", params: { name: "September 2026" }, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @period.name, body["name"]
  end

  test "creates a company status period with valid token" do
    assert_difference -> { CompanyStatusPeriod.count }, 1 do
      post api_company_status_periods_url,
        params: {
          name: "October 2026",
          slug: "october-2026",
          current: false,
          position: 2,
          starts_on: "2026-10-01",
          ends_on: "2026-10-31"
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "October 2026", body["name"]
    assert_equal "october-2026", body["slug"]
  end

  test "updates a company status period with valid token" do
    patch api_company_status_period_url(@period.id),
      params: {
        name: "September 2026 Updated",
        current: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "September 2026 Updated", body["name"]
    assert_equal 3, body["position"]
  end

  test "deletes a company status period with valid token" do
    assert_difference -> { CompanyStatusPeriod.count }, -1 do
      delete api_company_status_period_url(@period.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil CompanyStatusPeriod.find_by(id: @period.id)
  end

  test "rejects requests without a token" do
    get api_company_status_periods_url
    assert_response :unauthorized
  end

  test "returns not found for missing company status period" do
    get api_company_status_period_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end
