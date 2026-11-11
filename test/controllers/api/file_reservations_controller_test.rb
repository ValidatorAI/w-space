require "test_helper"

class Api::FileReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-file-reservations-test", name: "Reservation API Test Project")
    @holder = User.create!(name: "David", display_name: "David", email_address: "david@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
    @other = User.create!(name: "Jason", display_name: "Jason", email_address: "jason@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "creates a reservation with valid payload" do
    post api_file_reservations_url,
         params: {
           project_id: @project.id,
           patterns: ["app/models/*.rb"],
           holder_user_id: @holder.id,
           reason: "Refactor user model",
           ttl_seconds: 900
         },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @project.id, body["project_id"]
    assert_equal ["app/models/*.rb"], body["patterns"]
    assert_equal @holder.id, body["holder"]["id"]
  end

  test "returns conflict payload for overlapping exclusive reservation" do
    existing = FileReservation.create!(
      project: @project,
      patterns: ["app/models/*.rb"],
      holder: @holder,
      exclusive: true,
      expires_at: 1.hour.from_now
    )

    post api_file_reservations_url,
         params: {
           project_id: @project.id,
           patterns: ["app/models/user.rb"],
           holder_user_id: @other.id,
           reason: "Competing edit"
         },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :conflict
    body = JSON.parse(response.body)
    assert_equal "conflict", body["error"]
    assert_includes body["conflicting"].map { |entry| entry["id"] }, existing.id
    assert_includes body["conflicting"].first["holder_name"], @holder.name
  end

  test "rejects invalid pattern payloads" do
    post api_file_reservations_url,
         params: {
           project_id: @project.id,
           patterns: [],
           holder_user_id: @holder.id
         },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :unprocessable_entity
    assert_equal "invalid patterns", JSON.parse(response.body)["error"]
  end

  test "rejects unknown holder users" do
    post api_file_reservations_url,
         params: {
           project_id: @project.id,
           patterns: ["app/models/*.rb"],
           holder_user_id: -999
         },
         headers: { "Authorization" => "Bearer test-token" }

    assert_response :unprocessable_entity
    assert_equal "unknown holder", JSON.parse(response.body)["error"]
  end

  test "returns forbidden when non-holder renews a reservation" do
    reservation = FileReservation.create!(project: @project, patterns: ["app/models/*.rb"], holder: @holder, expires_at: 1.hour.from_now)

    patch api_file_reservation_url(reservation.id),
          params: { holder_user_id: @other.id, ttl_seconds: 300 },
          headers: { "Authorization" => "Bearer test-token" }

    assert_response :forbidden
    assert_equal "not holder", JSON.parse(response.body)["error"]
  end

  test "allows holder to renew and extend the expiry" do
    reservation = FileReservation.create!(project: @project, patterns: ["app/models/*.rb"], holder: @holder, expires_at: 1.minute.from_now)
    original_expiry = reservation.expires_at

    patch api_file_reservation_url(reservation.id),
          params: { holder_user_id: @holder.id, ttl_seconds: 900 },
          headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    reservation.reload
    assert reservation.expires_at > original_expiry
  end

  test "returns gone when renewing an expired reservation" do
    reservation = FileReservation.create!(project: @project, patterns: ["app/models/*.rb"], holder: @holder, expires_at: 5.minutes.ago)

    patch api_file_reservation_url(reservation.id),
          params: { holder_user_id: @holder.id, ttl_seconds: 900 },
          headers: { "Authorization" => "Bearer test-token" }

    assert_response :gone
    assert_equal "expired", JSON.parse(response.body)["error"]
  end

  test "delete is idempotent and always returns no content" do
    reservation = FileReservation.create!(project: @project, patterns: ["app/models/*.rb"], holder: @holder, expires_at: 1.hour.from_now)

    delete api_file_reservation_url(reservation.id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :no_content

    delete api_file_reservation_url(reservation.id), headers: { "Authorization" => "Bearer test-token" }
    assert_response :no_content
  end
end
