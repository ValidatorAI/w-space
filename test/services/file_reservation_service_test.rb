require "test_helper"

class FileReservationServiceTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(path: "/tmp/service-file-reservation-test", name: "Service Reservation Test")
    @holder = User.create!(name: "David", display_name: "David", email_address: "david@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
    @other = User.create!(name: "Jason", display_name: "Jason", email_address: "jason@example.com", password: "secret123456", password_confirmation: "secret123456", role: "administrator")
  end

  test "conflict detection matches the model logic" do
    existing = @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.hour.from_now
    )

    conflicts = FileReservationService.conflicts?(project: @project, patterns: ["app/models/user.rb"])
    assert_equal [existing.id], conflicts.map(&:id)
  end

  test "reserve raises a conflict error with conflicting rows" do
    @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.hour.from_now
    )

    error = assert_raises(FileReservationService::ConflictError) do
      FileReservationService.reserve(
        project: @project,
        patterns: ["app/models/user.rb"],
        holder: @other,
        reason: "Competing edit",
        ttl_seconds: 300
      )
    end

    assert_equal 1, error.conflicts.count
    assert_equal @holder.name, error.conflicts.first[:holder_name]
  end

  test "renew enforces holder ownership and extends expiry" do
    reservation = @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.minute.from_now
    )

    renewed = FileReservationService.renew(reservation: reservation, holder: @holder, ttl_seconds: 900)
    assert_equal reservation.id, renewed.id
    assert renewed.expires_at > reservation.expires_at

    assert_raises(FileReservationService::ForbiddenError) do
      FileReservationService.renew(reservation: reservation, holder: @other, ttl_seconds: 900)
    end
  end

  test "release is idempotent and refuses non-holders" do
    reservation = @project.file_reservations.create!(
      patterns: ["app/models/*.rb"],
      holder: @holder,
      expires_at: 1.hour.from_now
    )

    assert_nil FileReservationService.release(reservation: reservation, holder: @holder)
    assert_nil FileReservationService.release(reservation: reservation, holder: @holder)

    assert_raises(FileReservationService::ForbiddenError) do
      FileReservationService.release(reservation: reservation, holder: @other)
    end
  end
end
