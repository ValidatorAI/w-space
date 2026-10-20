class FileReservation < ApplicationRecord
  belongs_to :project

  validates :patterns, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :exclusive, -> { where(exclusive: true) }
  scope :shared, -> { where(exclusive: false) }

  before_validation :set_default_expiry, on: :create

  after_create_commit :broadcast_acquired
  after_destroy_commit :broadcast_released

  def self.cleanup_expired!
    expired.destroy_all
  end

  def expired?
    expires_at <= Time.current
  end

  def renew!(ttl_seconds: 3600)
    update!(expires_at: Time.current + ttl_seconds.seconds)
  end

  def conflicts_with?(other_patterns)
    patterns.any? do |my_pattern|
      other_patterns.any? do |other_pattern|
        patterns_overlap?(my_pattern, other_pattern)
      end
    end
  end

  def conflicting_reservations
    project.file_reservations
           .active
           .exclusive
           .where.not(id: id)
           .select { |r| r.conflicts_with?(patterns) }
  end

  def time_remaining
    [ expires_at - Time.current, 0 ].max
  end

  private

  def set_default_expiry
    self.expires_at ||= 1.hour.from_now
  end

  def patterns_overlap?(pattern1, pattern2)
    # Symmetric glob matching: either pattern matches the other
    File.fnmatch?(pattern1, pattern2, File::FNM_PATHNAME | File::FNM_DOTMATCH) ||
      File.fnmatch?(pattern2, pattern1, File::FNM_PATHNAME | File::FNM_DOTMATCH) ||
      shared_prefix_overlap?(pattern1, pattern2)
  end

  def shared_prefix_overlap?(pattern1, pattern2)
    # Check if patterns share a common non-wildcard prefix that indicates overlap
    # e.g., "src/api/*.rb" and "src/api/users.rb" overlap
    base1 = pattern1.gsub(/\*.*$/, "")
    base2 = pattern2.gsub(/\*.*$/, "")
    return false if base1.empty? && base2.empty?

    base1.start_with?(base2) || base2.start_with?(base1)
  end

  def broadcast_acquired
    return unless project.project_room

    SystemMessage.post(
      room: project.project_room,
      type: :reservation_acquired,
      mirror_to_meta: false,
      data: { patterns: Array(patterns).join(", ") }
    )
  end

  def broadcast_released
    return unless project.project_room

    SystemMessage.post(
      room: project.project_room,
      type: :reservation_released,
      mirror_to_meta: false,
      data: { patterns: Array(patterns).join(", ") }
    )
  end
end
