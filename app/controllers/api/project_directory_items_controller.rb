module Api
  class ProjectDirectoryItemsController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      items = project.directory_items.ordered
      if params[:active].present?
        items = items.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = items.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_items = items.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        directory_items: paged_items.map { |item| serialize(item) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.directory_items.find_by(id: params[:id])
      return render json: { error: "Directory item not found" }, status: :not_found unless item

      render json: serialize(item)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.directory_items.new(directory_item_params)
      process_file_storage(project, item, params[:file])

      unless item.save
        return render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(item), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.directory_items.find_by(id: params[:id])
      return render json: { error: "Directory item not found" }, status: :not_found unless item

      item.assign_attributes(directory_item_params)
      process_file_storage(project, item, params[:file])

      if item.save
        render json: serialize(item)
      else
        render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      item = project.directory_items.find_by(id: params[:id])
      return render json: { error: "Directory item not found" }, status: :not_found unless item

      if item.file_path.present?
        begin
          _, _, full_path = resolve_storage_path(project, item.file_path)
          FileUtils.rm_rf(full_path) if File.exist?(full_path)
        rescue ArgumentError
          # Ignore path resolution issues when deleting
        end
      end

      item.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def directory_item_params
      params.permit(:parent_id, :name, :item_type, :file_path, :content, :position, :active)
    end

    def process_file_storage(project, item, uploaded_file)
      if uploaded_file.present?
        filename = if uploaded_file.respond_to?(:original_filename)
                     uploaded_file.original_filename
        else
                     File.basename(uploaded_file.to_s)
        end

        item.name = filename if item.name.blank?
        item.item_type = "file" if item.item_type.blank?

        rel_path = if params[:file_path].present?
                     params[:file_path]
                   elsif item.parent.present?
                     File.join(item.parent.relative_path, (item.name.presence || filename))
                   else
                     item.name.presence || filename
                   end

        base_dir, cleaned_rel, full_path = resolve_storage_path(project, rel_path)

        FileUtils.mkdir_p(File.dirname(full_path))
        File.open(full_path, "wb") do |f|
          if uploaded_file.respond_to?(:read)
            f.write(uploaded_file.read)
          else
            f.write(uploaded_file.to_s)
          end
        end

        item.file_path = cleaned_rel
        if item.content.blank?
          begin
            read_content = File.read(full_path)
            item.content = read_content if read_content.valid_encoding?
          rescue StandardError
            # Non-text or binary files
          end
        end
      elsif item.directory?
        rel_path = params[:file_path].presence || item.file_path.presence || item.name
        if rel_path.present?
          base_dir, cleaned_rel, full_path = resolve_storage_path(project, rel_path)
          FileUtils.mkdir_p(full_path)
          item.file_path = cleaned_rel
        end
      elsif item.file? && item.file_path.present? && item.content.present?
        base_dir, cleaned_rel, full_path = resolve_storage_path(project, item.file_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, item.content)
        item.file_path = cleaned_rel
      end
    end

    def resolve_storage_path(project, relative_path)
      base_dir = Rails.root.join("storage", "projects", project.id.to_s).expand_path
      FileUtils.mkdir_p(base_dir) unless Dir.exist?(base_dir)

      cleaned_rel = relative_path.to_s.strip.delete_prefix("/")
      cleaned_rel = "file" if cleaned_rel.blank?
      target_path = base_dir.join(cleaned_rel).expand_path

      unless target_path.to_s.start_with?(base_dir.to_s)
        raise ArgumentError, "Invalid file path (directory traversal not allowed)"
      end

      [ base_dir, cleaned_rel, target_path ]
    end

    def serialize(item)
      item.as_json
    end
  end
end
