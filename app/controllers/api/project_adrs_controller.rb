module Api
  class ProjectAdrsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      adrs = project.adrs.ordered
      if params[:active].present?
        adrs = adrs.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = adrs.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_adrs = adrs.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        adrs: paged_adrs.map { |adr| serialize(adr) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      adr = project.adrs.find_by(id: params[:id])
      return render json: { error: "ADR not found" }, status: :not_found unless adr

      render json: serialize(adr)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      adr = project.adrs.new(adr_params)
      unless adr.save
        return render json: { error: adr.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(adr), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      adr = project.adrs.find_by(id: params[:id])
      return render json: { error: "ADR not found" }, status: :not_found unless adr

      if adr.update(adr_params)
        render json: serialize(adr)
      else
        render json: { error: adr.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      adr = project.adrs.find_by(id: params[:id])
      return render json: { error: "ADR not found" }, status: :not_found unless adr

      adr.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def adr_params
      params.permit(:identifier, :title, :decision_date, :status, :file_path, :active, :position)
    end

    def serialize(adr)
      adr.as_json
    end
  end
end
