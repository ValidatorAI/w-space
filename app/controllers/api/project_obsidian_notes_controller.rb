module Api
  class ProjectObsidianNotesController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      notes = project.obsidian_notes.ordered
      if params[:active].present?
        notes = notes.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      count = notes.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_notes = notes.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        obsidian_notes: paged_notes.map { |note| serialize(note) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      note = project.obsidian_notes.find_by(id: params[:id])
      return render json: { error: "Obsidian note not found" }, status: :not_found unless note

      render json: serialize(note)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      note = project.obsidian_notes.new(obsidian_note_params)
      process_file_storage(project, note, params[:file])

      unless note.save
        return render json: { error: note.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(note), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      note = project.obsidian_notes.find_by(id: params[:id])
      return render json: { error: "Obsidian note not found" }, status: :not_found unless note

      note.assign_attributes(obsidian_note_params)
      process_file_storage(project, note, params[:file])

      if note.save
        render json: serialize(note)
      else
        render json: { error: note.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      note = project.obsidian_notes.find_by(id: params[:id])
      return render json: { error: "Obsidian note not found" }, status: :not_found unless note

      if note.internal_source? && note.html_source_path.present?
        begin
          _, _, full_path = resolve_storage_path(project, note.html_source_path)
          FileUtils.rm_rf(full_path) if File.exist?(full_path)
        rescue ArgumentError
          # Ignore path resolution issues when deleting
        end
      end

      note.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def obsidian_note_params
      params.permit(:title, :tags, :content, :html_source_type, :html_source_path, :active, :position)
    end

    def process_file_storage(project, note, uploaded_file)
      if uploaded_file.present?
        filename = if uploaded_file.respond_to?(:original_filename)
                     uploaded_file.original_filename
        else
                     File.basename(uploaded_file.to_s)
        end

        note.title = filename if note.title.blank?
        note.html_source_type = "internal_file" if note.html_source_type.blank?

        rel_path = params[:html_source_path].presence || note.html_source_path.presence || filename
        base_dir, cleaned_rel, full_path = resolve_storage_path(project, rel_path)

        FileUtils.mkdir_p(File.dirname(full_path))
        File.open(full_path, "wb") do |f|
          if uploaded_file.respond_to?(:read)
            f.write(uploaded_file.read)
          else
            f.write(uploaded_file.to_s)
          end
        end

        note.html_source_path = cleaned_rel
        if note.content.blank?
          begin
            read_content = File.read(full_path)
            note.content = read_content if read_content.valid_encoding?
          rescue StandardError
            # Non-text or binary files
          end
        end
      elsif note.internal_source? && note.html_source_path.present? && note.content.present?
        base_dir, cleaned_rel, full_path = resolve_storage_path(project, note.html_source_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, note.content)
        note.html_source_path = cleaned_rel
      end
    end

    def resolve_storage_path(project, relative_path)
      base_dir = Rails.root.join("storage", "projects", project.id.to_s).expand_path
      FileUtils.mkdir_p(base_dir) unless Dir.exist?(base_dir)

      cleaned_rel = relative_path.to_s.strip.delete_prefix("/")
      cleaned_rel = "note.html" if cleaned_rel.blank?
      target_path = base_dir.join(cleaned_rel).expand_path

      unless target_path.to_s.start_with?(base_dir.to_s)
        raise ArgumentError, "Invalid file path (directory traversal not allowed)"
      end

      [ base_dir, cleaned_rel, target_path ]
    end

    def serialize(note)
      note.as_json
    end
  end
end
