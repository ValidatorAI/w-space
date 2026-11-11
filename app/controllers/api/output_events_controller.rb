module Api
  class OutputEventsController < Api::BaseController
    def index
      scope = OutputEvent.all
      scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
      scope = scope.where(event_id: params[:event_id]) if params[:event_id].present?
      scope = scope.where(group_id: params[:group_id]) if params[:group_id].present?
      scope = scope.where(synced: parse_boolean(params[:synced])) if params[:synced].present?
      scope = scope.where("created_at >= ?", parse_datetime(params[:since])) if params[:since].present?
      scope = scope.where("created_at <= ?", parse_datetime(params[:until])) if params[:until].present?

      scope = scope.order(created_at: :desc, id: :desc)
      limit = params[:limit].presence.to_i
      limit = 50 if limit <= 0
      limit = [limit, 500].min
      count = scope.count
      events = scope.limit(limit)

      render json: {
        count: count,
        output_events: events.map { |event| serialize_event(event) }
      }
    end

    def show
      event = OutputEvent.find_by(id: params[:id])
      return render json: { error: "Output event not found" }, status: :not_found unless event

      render json: serialize_event(event)
    end

    def redeliver
      event = OutputEvent.find_by(id: params[:id])
      return render json: { error: "Output event not found" }, status: :not_found unless event
      return render json: { error: "delivery not configured" }, status: :conflict if ENV["OUTPUT_EVENTS_URL"].blank?

      begin
        OutputEvents::DeliveryClient.new.deliver(event)
        event.update!(synced: true)
        render json: serialize_event(event)
      rescue OutputEvents::DeliveryClient::TransientDeliveryError => e
        render json: { error: e.message }, status: :bad_gateway
      rescue OutputEvents::DeliveryClient::PermanentDeliveryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end

    private

    def serialize_event(event)
      event.attributes.slice("id", "event_type", "event_id", "group_id", "event_data", "synced", "created_at", "updated_at")
    end

    def parse_boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def parse_datetime(value)
      Time.zone.parse(value.to_s)
    end
  end
end
