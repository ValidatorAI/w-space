module Api
  class ProjectBottlenecksController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      bottlenecks = filter_bottlenecks(project.bottlenecks.ordered)
      count = bottlenecks.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_bottlenecks = bottlenecks.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_bottlenecks: paged_bottlenecks.map { |item| serialize(item) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      bottleneck = project.bottlenecks.find_by(id: params[:id])
      return render json: { error: "Project bottleneck not found" }, status: :not_found unless bottleneck

      render json: serialize(bottleneck)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      bottleneck = project.bottlenecks.new(bottleneck_params)
      unless bottleneck.save
        return render json: { error: bottleneck.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(bottleneck), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      bottleneck = project.bottlenecks.find_by(id: params[:id])
      return render json: { error: "Project bottleneck not found" }, status: :not_found unless bottleneck

      attrs = bottleneck_params.to_h
      if params.key?(:resolved)
        resolved_val = ActiveModel::Type::Boolean.new.cast(params[:resolved])
        if resolved_val
          attrs[:resolved_at] ||= Time.current
          attrs[:severity] = "resolved" if attrs[:severity].blank? || attrs[:severity] == "active"
        else
          attrs[:resolved_at] = nil
          attrs[:severity] = "active" if attrs[:severity] == "resolved"
        end
      end

      if bottleneck.update(attrs)
        render json: serialize(bottleneck)
      else
        render json: { error: bottleneck.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      bottleneck = project.bottlenecks.find_by(id: params[:id])
      return render json: { error: "Project bottleneck not found" }, status: :not_found unless bottleneck

      bottleneck.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def bottleneck_params
      params.permit(:title, :description, :severity, :position, :resolved_at)
    end

    def filter_bottlenecks(scope)
      if params[:active].present?
        is_active = ActiveModel::Type::Boolean.new.cast(params[:active])
        scope = is_active ? scope.active : scope.resolved
      end

      if params[:severity].present?
        scope = scope.where(severity: params[:severity])
      end

      # Date range filters for created_at
      from_date = params[:created_at_gt].presence || params[:from].presence || params[:starts_at].presence || params[:start_date].presence
      if from_date.present?
        begin
          parsed_from = Time.zone.parse(from_date.to_s)
          scope = scope.where("created_at > ?", parsed_from) if parsed_from
        rescue ArgumentError
          return scope.none
        end
      end

      if params[:created_at_gte].present?
        begin
          parsed_from_gte = Time.zone.parse(params[:created_at_gte].to_s)
          scope = scope.where("created_at >= ?", parsed_from_gte) if parsed_from_gte
        rescue ArgumentError
          return scope.none
        end
      end

      to_date = params[:created_at_lt].presence || params[:to].presence || params[:ends_at].presence || params[:end_date].presence
      if to_date.present?
        begin
          parsed_to = Time.zone.parse(to_date.to_s)
          scope = scope.where("created_at < ?", parsed_to) if parsed_to
        rescue ArgumentError
          return scope.none
        end
      end

      if params[:created_at_lte].present?
        begin
          parsed_to_lte = Time.zone.parse(params[:created_at_lte].to_s)
          scope = scope.where("created_at <= ?", parsed_to_lte) if parsed_to_lte
        rescue ArgumentError
          return scope.none
        end
      end

      scope
    end

    def serialize(bottleneck)
      bottleneck.as_json
    end
  end
end
