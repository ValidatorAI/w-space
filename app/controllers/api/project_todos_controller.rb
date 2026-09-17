module Api
  class ProjectTodosController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      todos = filter_todos(project.todos.ordered)
      count = todos.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_todos = todos.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        project_todos: paged_todos.map { |todo| serialize(todo) }
      }
    end

    def show
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      todo = project.todos.find_by(id: params[:id])
      return render json: { error: "Project todo not found" }, status: :not_found unless todo

      render json: serialize(todo)
    end

    def create
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      todo = project.todos.new(todo_params)
      if todo.completed && todo.completed_at.blank?
        todo.completed_at = Time.current
      end

      unless todo.save
        return render json: { error: todo.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(todo), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      todo = project.todos.find_by(id: params[:id])
      return render json: { error: "Project todo not found" }, status: :not_found unless todo

      attrs = todo_params.to_h
      if params.key?(:completed)
        completed_val = ActiveModel::Type::Boolean.new.cast(params[:completed])
        if completed_val && !todo.completed? && !attrs.key?(:completed_at)
          attrs[:completed_at] = Time.current
        elsif !completed_val && todo.completed? && !attrs.key?(:completed_at)
          attrs[:completed_at] = nil
        end
      end

      if todo.update(attrs)
        render json: serialize(todo)
      else
        render json: { error: todo.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      project = find_project
      return render json: { error: "Project not found" }, status: :not_found unless project

      todo = project.todos.find_by(id: params[:id])
      return render json: { error: "Project todo not found" }, status: :not_found unless todo

      todo.destroy
      head :no_content
    end

    private

    def find_project
      Project.find_by(id: params[:project_id]) || Project.find_by(slug: params[:project_id])
    end

    def todo_params
      params.permit(:title, :meta_text, :completed, :completed_at, :position)
    end

    def filter_todos(scope)
      if params[:completed].present?
        is_completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
        scope = is_completed ? scope.completed : scope.pending
      elsif params[:active].present?
        is_active = ActiveModel::Type::Boolean.new.cast(params[:active])
        scope = is_active ? scope.pending : scope.completed
      end

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

    def serialize(todo)
      todo.as_json
    end
  end
end
