module Api
  class ProjectExternalAssetsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      assets = project.external_assets.ordered
      if params[:active].present?
        assets = assets.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = assets.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_assets = assets.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        external_assets: paged_assets.map { |asset| serialize(asset) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      asset = project.external_assets.find_by(id: params[:id])
      return render json: { error: "External asset not found" }, status: :not_found unless asset

      render json: serialize(asset)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      asset = project.external_assets.new(external_asset_params)
      unless asset.save
        return render json: { error: asset.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(asset), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      asset = project.external_assets.find_by(id: params[:id])
      return render json: { error: "External asset not found" }, status: :not_found unless asset

      if asset.update(external_asset_params)
        render json: serialize(asset)
      else
        render json: { error: asset.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      asset = project.external_assets.find_by(id: params[:id])
      return render json: { error: "External asset not found" }, status: :not_found unless asset

      asset.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def external_asset_params
      params.permit(:title, :url, :doc_type, :icon, :source_type, :meta_text, :active, :position)
    end

    def serialize(asset)
      asset.as_json
    end
  end
end
