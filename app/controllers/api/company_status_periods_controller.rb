module Api
  class CompanyStatusPeriodsController < Api::BaseController
    PERIOD_FIELDS = %i[
      id account_id name slug current starts_on ends_on position
      created_at updated_at
    ].freeze

    def index
      periods = CompanyStatusPeriod.ordered
      render json: {
        count: periods.count,
        company_status_periods: periods.map { |period| serialize(period) }
      }
    end

    def show
      period = find_period(params[:id])
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      render json: serialize(period)
    end

    def current
      period = CompanyStatusPeriod.current.first || CompanyStatusPeriod.ordered.first
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      render json: serialize(period)
    end

    def by_slug
      period = CompanyStatusPeriod.find_by(slug: params[:slug])
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      render json: serialize(period)
    end

    def by_name
      name = params[:name].to_s.strip
      return render json: { error: "Name is required" }, status: :bad_request if name.blank?

      period = CompanyStatusPeriod.where("LOWER(name) = ?", name.downcase).first
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      render json: serialize(period)
    end

    def create
      period = CompanyStatusPeriod.new(period_params)
      unless period.save
        return render json: { error: period.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(period), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      period = find_period(params[:id])
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      if period.update(period_params)
        render json: serialize(period)
      else
        render json: { error: period.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      period = find_period(params[:id])
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      period.destroy
      head :no_content
    end

    private

    def find_period(id)
      CompanyStatusPeriod.find_by(id: id) || CompanyStatusPeriod.find_by(slug: id)
    end

    def period_params
      params.permit(:account_id, :name, :slug, :current, :starts_on, :ends_on, :position)
    end

    def serialize(period)
      payload = period.as_json(only: PERIOD_FIELDS)
      payload["company_status_items"] = period.company_status_items.order(position: :asc, created_at: :asc).map(&:as_status_payload)
      payload
    end
  end
end
