module Api
  class FileReservationsController < Api::BaseController
    def index
      scope = FileReservation.includes(:holder).order(created_at: :desc)
      project = find_project(params[:project_id])
      scope = scope.where(project_id: project.id) if project.present?
      scope = scope.where("expires_at > ?", Time.current) unless params[:include_expired].to_s == "true"

      render json: scope.map { |reservation| serialize_reservation(reservation) }
    end

    def show
      reservation = FileReservation.find_by(id: params[:id])
      return render json: { error: "Reservation not found" }, status: :not_found unless reservation

      render json: serialize_reservation(reservation)
    end

    def create
      project = find_project_or_render_not_found(params[:project_id])
      return if project.nil?

      patterns = normalize_patterns_param(params[:patterns])
      unless valid_patterns?(patterns)
        return render json: { error: "invalid patterns" }, status: :unprocessable_entity
      end

      holder = resolve_holder
      unless holder
        return render json: { error: "unknown holder" }, status: :unprocessable_entity
      end

      ttl_seconds = params[:ttl_seconds].presence || 3600
      exclusive = params.key?(:exclusive) ? ActiveModel::Type::Boolean.new.cast(params[:exclusive]) : true

      begin
        reservation = FileReservationService.reserve(
          project: project,
          patterns: patterns,
          holder: holder,
          exclusive: exclusive,
          reason: params[:reason].presence,
          ttl_seconds: ttl_seconds
        )
      rescue FileReservationService::ConflictError => e
        return render json: { error: "conflict", conflicting: e.conflicts }, status: :conflict
      end

      render json: serialize_reservation(reservation), status: :created
    end

    def update
      reservation = FileReservation.find_by(id: params[:id])
      return render json: { error: "Reservation not found" }, status: :not_found unless reservation

      holder = resolve_holder
      if params[:holder_user_id].present? && holder.nil?
        return render json: { error: "unknown holder" }, status: :unprocessable_entity
      end

      if reservation.expired?
        return render json: { error: "expired" }, status: :gone
      end

      begin
        renewed = FileReservationService.renew(
          reservation: reservation,
          holder: holder,
          ttl_seconds: params[:ttl_seconds].presence || 3600
        )
      rescue FileReservationService::ForbiddenError
        return render json: { error: "not holder" }, status: :forbidden
      rescue FileReservationService::ExpiredError
        return render json: { error: "expired" }, status: :gone
      end

      render json: serialize_reservation(renewed)
    end

    def destroy
      reservation = FileReservation.find_by(id: params[:id])
      reservation&.destroy
      head :no_content
    end

    private

    def resolve_holder
      holder_id = params[:holder_user_id].presence || params.dig(:reservation, :holder_user_id).presence
      return nil if holder_id.blank?

      User.find_by(id: holder_id)
    end

    def normalize_patterns_param(patterns)
      Array(patterns).flatten.filter_map do |pattern|
        value = pattern.to_s.strip
        next if value.blank?

        value
      end
    end

    def valid_patterns?(patterns)
      return false unless patterns.is_a?(Array)
      return false if patterns.empty?

      patterns.all? do |pattern|
        value = pattern.to_s.strip
        next false if value.empty?
        next false if value.start_with?("/")
        next false if value.include?("..")

        true
      end
    end

    def serialize_reservation(reservation)
      {
        id: reservation.id,
        project_id: reservation.project_id,
        patterns: Array(reservation.patterns),
        exclusive: reservation.exclusive,
        reason: reservation.reason,
        holder: reservation.holder ? { id: reservation.holder.id, name: reservation.holder.name } : nil,
        expires_at: reservation.expires_at.iso8601,
        time_remaining_seconds: reservation.time_remaining.to_i
      }
    end
  end
end
