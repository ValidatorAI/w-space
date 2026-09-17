module Api
  class CompanyStatusItemsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      items, count = filter_items
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_items = items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        company_status_items: paged_items.map { |item| serialize(item) }
      }
    end

    def show
      item = CompanyStatusItem.find_by(id: params[:id])
      return render json: { error: "Company status item not found" }, status: :not_found unless item

      render json: serialize(item)
    end

    def by_period
      period_id = params[:company_status_period_id].presence || params[:period_id].presence || params[:id].presence
      return render json: { error: "company_status_period_id is required" }, status: :bad_request if period_id.blank?

      period = CompanyStatusPeriod.find_by(id: period_id)
      return render json: { error: "Company status period not found" }, status: :not_found unless period

      items = period.company_status_items.ordered
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_items = items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: items.count,
        page: page,
        per_page: per_page,
        company_status_items: paged_items.map { |item| serialize(item) }
      }
    end

    def create
      item = CompanyStatusItem.new(item_params)
      unless item.save
        return render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(item), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      item = CompanyStatusItem.find_by(id: params[:id])
      return render json: { error: "Company status item not found" }, status: :not_found unless item

      if item.update(item_params)
        render json: serialize(item)
      else
        render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      item = CompanyStatusItem.find_by(id: params[:id])
      return render json: { error: "Company status item not found" }, status: :not_found unless item

      item.destroy
      head :no_content
    end

    def advanced_filter
      items, count = filter_items
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_items = items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        company_status_items: paged_items.map { |item| serialize(item) }
      }
    end

    private

    def filter_items
      scope = CompanyStatusItem.ordered

      if params[:company_status_period_id].present?
        scope = scope.where(company_status_period_id: params[:company_status_period_id])
      end

      if params[:category].present?
        scope = scope.where(category: params[:category])
      end

      if params[:position].present?
        scope = scope.where(position: params[:position])
      end

      if params[:title].present?
        scope = scope.where("LOWER(title) LIKE ?", "%#{params[:title].to_s.downcase}%")
      end

      if params[:owner].present?
        scope = scope.where("LOWER(owner) LIKE ?", "%#{params[:owner].to_s.downcase}%")
      end

      if params[:status].present?
        scope = scope.where(status: params[:status])
      end

      if params[:color].present?
        scope = scope.where(color: params[:color])
      end

      if params[:severity].present?
        scope = scope.where(severity: params[:severity])
      end

      if params[:detail_category].present?
        scope = scope.where(detail_category: params[:detail_category])
      end

      if params[:target_date].present?
        scope = scope.where(target_date: params[:target_date])
      end

      if params[:created_at_gt].present?
        begin
          scope = scope.where("created_at > ?", Time.zone.parse(params[:created_at_gt].to_s))
        rescue ArgumentError
          scope = scope.none
        end
      end

      if params[:created_at_lt].present?
        begin
          scope = scope.where("created_at < ?", Time.zone.parse(params[:created_at_lt].to_s))
        rescue ArgumentError
          scope = scope.none
        end
      end

      [ scope, scope.count ]
    end

    def item_params
      params.permit(
        :company_status_period_id, :category, :position, :title, :subtitle,
        :text, :description, :detail_category, :owner, :target_date,
        :status, :impact, :percent, :color, :evidence, :severity,
        :icon, :from_name, :to_name, actions: []
      )
    end

    def serialize(item)
      item.as_json
    end
  end
end
