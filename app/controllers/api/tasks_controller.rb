module Api
  class TasksController < Api::BaseController
    def index
      tasks = filter_tasks(AiTask.order(created_at: :desc, id: :desc))

      render json: {
        count: tasks.count,
        tasks: tasks.map { |task| serialize(task) }
      }
    end

    def show
      task = AiTask.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      render json: serialize(task)
    end

    def create
      task = AiTask.new(task_params)
      if task.save
        render json: serialize(task), status: :created
      else
        render json: { error: task.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def update
      task = AiTask.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      if params.key?(:dispatch_attempts)
        parsed_attempts = parse_dispatch_attempts!(params[:dispatch_attempts])
        return render json: { error: "dispatch_attempts must be an integer between 0 and #{AiTask::MAX_DISPATCH_ATTEMPTS}" }, status: :unprocessable_entity unless parsed_attempts

        task_params_with_reset = task_params
        if parsed_attempts.zero?
          task_params_with_reset[:dispatched] = false
          task_params_with_reset[:finished] = false
          task_params_with_reset[:dispatch_error] = nil
        end

        if task.update(task_params_with_reset)
          render json: serialize(task.reload)
        else
          render json: { error: task.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
        return
      end

      if task.update(task_params)
        render json: serialize(task.reload)
      else
        render json: { error: task.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      task = AiTask.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      task.destroy
      head :no_content
    end

    def task_cost
      task = AiTask.find_by(id: params[:task_id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      task.apply_task_cost!(params[:token_used], params[:usd_used])
      render json: serialize(task)
    end

    def children
      task = AiTask.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      descendants = collect_descendants(task)
      render json: {
        count: descendants.count,
        tasks: descendants.map { |item| serialize(item) }
      }
    end

    def parents
      task = AiTask.find_by(id: params[:id])
      return render json: { error: "Task not found" }, status: :not_found unless task

      ancestors = collect_ancestors(task)
      render json: {
        count: ancestors.count,
        tasks: ancestors.map { |item| serialize(item) }
      }
    end

    private

    def task_params
      params.permit(
        :adder_profile,
        :token_used,
        :token_budget,
        :usd_used,
        :usd_budget,
        :room_id,
        :project_id,
        :description,
        :assigneee_profile,
        :proposed_task_context,
        :actual_task_context,
        :dispatched,
        :finished,
        :added_to_kanban,
        :runned,
        :dispatch_attempts,
        :topic_id,
        :parent_task_id,
        :grand_parent_id,
        :importance,
        :level
      )
    end

    def parse_dispatch_attempts!(raw_value)
      return nil if raw_value.nil?

      value = raw_value.to_s.strip
      return nil if value.empty?
      return nil unless value.match?(/\A-?\d+\z/)

      integer_value = value.to_i
      return nil if integer_value.negative? || integer_value > AiTask::MAX_DISPATCH_ATTEMPTS

      integer_value
    end

    def filter_tasks(scope)
      if params[:room_id].present?
        scope = scope.where(room_id: params[:room_id])
      end

      if params[:project_id].present?
        scope = scope.where(project_id: params[:project_id])
      end

      if params[:grand_parent_id].present?
        scope = scope.where(grand_parent_id: params[:grand_parent_id])
      end

      if params.key?(:dispatched) || params.key?(:added_to_kanban)
        dispatched_value = params.key?(:dispatched) ? params[:dispatched] : params[:added_to_kanban]
        scope = scope.where(dispatched: ActiveModel::Type::Boolean.new.cast(dispatched_value))
      end

      if params.key?(:finished) || params.key?(:runned)
        finished_value = params.key?(:finished) ? params[:finished] : params[:runned]
        scope = scope.where(finished: ActiveModel::Type::Boolean.new.cast(finished_value))
      end

      if params[:topic_id].present? || params.key?(:topic_id)
        scope = scope.where(topic_id: params[:topic_id])
      end

      scope
    end

    def collect_descendants(task, visited = Set.new)
      return [] if visited.include?(task.id)

      visited << task.id
      task.child_tasks.flat_map do |child|
        [child] + collect_descendants(child, visited)
      end
    end

    def collect_ancestors(task, visited = Set.new)
      parent = task.parent_task
      return [] if parent.nil? || visited.include?(parent.id)

      visited << parent.id
      [parent] + collect_ancestors(parent, visited)
    end

    def serialize(task)
      task.as_json
    end
  end
end
