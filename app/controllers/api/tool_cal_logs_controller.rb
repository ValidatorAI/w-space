module Api
  class ToolCalLogsController < Api::BaseController
    def index
      scope = ToolCalLog.all
      scope = scope.where(used_tool_name: params[:used_tool_name]) if params[:used_tool_name].present?
      scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
      scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?
      scope = scope.where(topic_id: params[:topic_id]) if params[:topic_id].present?
      scope = scope.where(target_entity_id: params[:target_entity_id]) if params[:target_entity_id].present?
      scope = scope.where("created_date >= ?", parse_datetime(params[:start_date]).beginning_of_day) if params[:start_date].present?
      scope = scope.where("created_date <= ?", parse_datetime(params[:end_date]).end_of_day) if params[:end_date].present?

      scope = scope.ordered
      count = scope.count
      limit = params[:limit].presence&.to_i || 50
      limit = [limit, 500].min
      records = scope.limit(limit)

      render json: {
        count: count,
        tool_cal_logs: records.map { |record| serialize_tool_cal_log(record) }
      }
    end

    def show
      record = ToolCalLog.find_by(id: params[:id])
      return render json: { error: "Tool call log not found" }, status: :not_found unless record

      render json: serialize_tool_cal_log(record)
    end

    private

    def serialize_tool_cal_log(record)
      record.as_json(only: ToolCalLog.column_names.map(&:to_sym))
    end

    def parse_datetime(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      Time.current
    end
  end
end
