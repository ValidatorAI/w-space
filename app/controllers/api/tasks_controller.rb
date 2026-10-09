module Api
  class TasksController < Api::BaseController
    def index
      tasks = filter_tasks(Task.order(created_at: :desc, id: :desc))

      render json: {
        count: tasks.count,
        tasks: tasks.map { |task| serialize(task) }
      }
    end

    def show
      task = Task.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      render json: serialize(task)
    end

    def create
      task = Task.new(task_params)
      if task.save
        render json: serialize(task), status: :created
      else
        render json: { error: task.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def update
      task = Task.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      if task.update(task_params)
        render json: serialize(task)
      else
        render json: { error: task.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      task = Task.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      task.destroy
      head :no_content
    end

    private

    def task_params
      params.permit(
        :adder_profile,
        :token_used,
        :token_budget,
        :room_id,
        :project_id,
        :description,
        :assigneee_profile,
        :added_to_kanban,
        :runned,
        :parent_task_id,
        :importance,
        :level
      )
    end

    def filter_tasks(scope)
      if params[:room_id].present?
        scope = scope.where(room_id: params[:room_id])
      end

      if params[:project_id].present?
        scope = scope.where(project_id: params[:project_id])
      end

      if params.key?(:added_to_kanban)
        scope = scope.where(added_to_kanban: ActiveModel::Type::Boolean.new.cast(params[:added_to_kanban]))
      end

      if params.key?(:runned)
        scope = scope.where(runned: ActiveModel::Type::Boolean.new.cast(params[:runned]))
      end

      scope
    end

    def serialize(task)
      task.as_json
    end
  end
end
