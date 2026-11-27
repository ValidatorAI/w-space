class FileReservationService
  class ConflictError < StandardError
    attr_reader :conflicts

    def initialize(conflicts)
      @conflicts = Array(conflicts).map do |reservation|
        {
          id: reservation.id,
          patterns: Array(reservation.patterns),
          holder_name: reservation.holder&.name || "unknown",
          expires_at: reservation.expires_at.iso8601,
          time_remaining_seconds: reservation.time_remaining.to_i
        }
      end
      super("Reservation conflicts with existing files")
    end
  end

  class ForbiddenError < StandardError; end
  class ExpiredError < StandardError; end

  class << self
    def conflicts?(project:, patterns:)
      pattern_list = normalize_patterns(patterns)
      return [] if pattern_list.empty?

      project.file_reservations
             .active
             .exclusive
             .select { |reservation| reservation.conflicts_with?(pattern_list) }
    end

    def reserve(project:, patterns:, holder:, exclusive: true, reason: nil, ttl_seconds: nil)
      pattern_list = normalize_patterns(patterns)
      raise ArgumentError, "patterns cannot be blank" if pattern_list.empty?

      holder_record = coerce_holder(holder)
      conflict_rows = conflicts?(project: project, patterns: pattern_list)
      raise ConflictError, conflict_rows if conflict_rows.any?

      project.file_reservations.create!(
        patterns: pattern_list,
        holder: holder_record,
        exclusive: exclusive,
        reason: reason,
        expires_at: Time.current + (ttl_seconds.presence || 3600).to_i.seconds
      )
    end

    def renew(reservation:, holder:, ttl_seconds: 3600)
      raise ExpiredError, "reservation is expired" if reservation.expired?

      holder_record = coerce_holder(holder)
      if reservation.holder_user_id.present? && holder_record.present? && reservation.holder_user_id != holder_record.id
        raise ForbiddenError, "not holder"
      end

      if reservation.holder_user_id.present? && holder_record.blank?
        raise ForbiddenError, "not holder"
      end

      reservation.renew!(ttl_seconds: ttl_seconds.to_i)
      reservation
    end

    def release(reservation:, holder: nil)
      return nil if reservation.nil?

      holder_record = coerce_holder(holder)
      if reservation.holder_user_id.present? && holder_record.present? && reservation.holder_user_id != holder_record.id
        raise ForbiddenError, "not holder"
      end

      if reservation.holder_user_id.present? && holder_record.blank?
        raise ForbiddenError, "not holder"
      end

      reservation.destroy
      nil
    end

    private

    def normalize_patterns(patterns)
      Array(patterns).flatten.filter_map do |pattern|
        value = pattern.to_s.strip
        next if value.blank?

        value
      end.uniq
    end

    def coerce_holder(holder)
      return holder if holder.is_a?(User)
      return nil if holder.blank?

      User.find_by(id: holder)
    end
  end
end
