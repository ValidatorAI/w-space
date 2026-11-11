module Api
  class ProjectsController < Api::BaseController
    PROJECT_FIELDS = %i[
      id name slug path description private short_code current_phase
      progress_percent roadmap recently_completed budget_total budget_spent
      created_at updated_at
    ].freeze

    def index
      render json: Project.all.as_json(only: PROJECT_FIELDS)
    end

    def show
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      render json: serialize_project(project)
    end

    def create
      payload = project_params
      path = payload[:path].presence
      return render json: { error: "Path is required" }, status: :unprocessable_entity if path.blank?

      existing = Project.find_by(path: path)
      if existing
        return render json: serialize_project(existing).merge("created" => false), status: :ok
      end

      project = Project.new(payload)
      unless project.save
        return render json: { error: project.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      OutputEvents::Recorder.record(
        event_type: "project_created",
        event_id: project.id,
        group_id: SecureRandom.uuid,
        actor: nil,
        target_type: "Project",
        data: { "slug" => project.slug, "path" => project.path, "member_user_ids" => [] }
      )

      render json: serialize_project(project).merge("created" => true), status: :created
    end

    def update
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      project.assign_attributes(project_params)
      unless project.save
        return render json: { error: project.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      if project.previous_changes.except("updated_at").any?
        OutputEvents::Recorder.record(
          event_type: "project_updated",
          event_id: project.id,
          group_id: SecureRandom.uuid,
          actor: nil,
          target_type: "Project",
          data: { "changed_fields" => project.previous_changes.except("updated_at").keys.map(&:to_s) }
        )
      end

      render json: serialize_project(project)
    end

    def destroy
      project = find_project(params[:id])
      return render json: { error: "Project not found" }, status: :not_found unless project

      project.destroy!
      head :no_content
    end

    private

    def project_params
      source = params[:project].presence || params
      source.permit(
        :name,
        :path,
        :description,
        :private,
        :short_code,
        :current_phase,
        :roadmap,
        :recently_completed,
        :budget_total,
        :budget_spent
      )
    end

    def serialize_project(project)
      payload = project.as_json(only: PROJECT_FIELDS)
      payload["budget_total"] = normalize_numeric(payload["budget_total"])
      payload["budget_spent"] = normalize_numeric(payload["budget_spent"])
      payload["progress_percent"] = normalize_numeric(payload["progress_percent"])
      payload
    end

    def normalize_numeric(value)
      return value if value.nil?

      if value.is_a?(String)
        value = BigDecimal(value, exception: false)
        return value if value.nil?
      end

      return value unless value.is_a?(Numeric)

      number = value.to_f
      number.to_i == number ? number.to_i : number
    end
  end
end

