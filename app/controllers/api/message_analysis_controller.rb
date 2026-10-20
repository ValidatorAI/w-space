module Api
  class MessageAnalysisController < Api::BaseController
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      analyses = build_scope
      count = analyses.count
      page = [ params[:page].presence&.to_i || 1, 1 ].max
      per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
      paged_analyses = analyses.offset((page - 1) * per_page).limit(per_page)

      render json: {
        count: count,
        page: page,
        per_page: per_page,
        message_analysis: paged_analyses.map { |analysis| serialize(analysis) }
      }
    end

    def show
      analysis = MessageAnalysis.find_by(id: params[:id])
      return render json: { error: "Message analysis not found" }, status: :not_found unless analysis

      render json: serialize(analysis)
    end

    def create
      message = Message.find_by(id: params[:message_id])
      return render json: { error: "Message not found" }, status: :not_found unless message

      analysis = MessageAnalysis.new(message: message, **message_analysis_params.to_h)
      unless analysis.save
        return render json: { error: analysis.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(analysis), status: :created
    end

    def update
      analysis = MessageAnalysis.find_by(id: params[:id])
      return render json: { error: "Message analysis not found" }, status: :not_found unless analysis

      if params[:message_id].present? || params.key?(:message_id)
        message = Message.find_by(id: params[:message_id])
        return render json: { error: "Message not found" }, status: :not_found if params[:message_id].present? && message.nil?

        analysis.message = message if message
      end

      if analysis.update(message_analysis_params)
        render json: serialize(analysis)
      else
        render json: { error: analysis.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      analysis = MessageAnalysis.find_by(id: params[:id])
      return render json: { error: "Message analysis not found" }, status: :not_found unless analysis

      analysis.destroy
      head :no_content
    end

    private

    def build_scope
      scope = MessageAnalysis.order(created_at: :desc)

      if params[:message_id].present?
        scope = scope.where(message_id: params[:message_id])
      end

      if params[:importance_level].present?
        scope = scope.where(importance_level: params[:importance_level])
      end

      if params[:is_a_response].present?
        scope = scope.where(is_a_response: ActiveModel::Type::Boolean.new.cast(params[:is_a_response]))
      end

      scope
    end

    def message_analysis_params
      params.permit(:message_id, :importance_level, :message_content_summary, :message_type, :tags, :is_a_response)
    end

    def serialize(analysis)
      analysis.as_json
    end
  end
end
