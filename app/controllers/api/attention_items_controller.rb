module Api
  class AttentionItemsController < Api::BaseController
    ATTENTION_ITEM_FIELDS = %i[
      id category title meta_text due_at overdue status
      project_id room_id user_id source_id source_type target_id target_type
      action_label ai_confirm created_at updated_at resolved_at resolved_by_id
    ].freeze
    DEFAULT_PER_PAGE = 40
    MAX_PER_PAGE = 200

    def index
      attention_items = build_scope
      count = attention_items.count

      if params[:page].present?
        per_page = params[:per_page].presence&.to_i&.clamp(1, MAX_PER_PAGE) || DEFAULT_PER_PAGE
        page = [ params[:page].to_i, 1 ].max
        attention_items = attention_items.offset((page - 1) * per_page).limit(per_page)

        render json: {
          count: count,
          page: page,
          per_page: per_page,
          attention_items: attention_items.map { |attention_item| serialize(attention_item) }
        }
      else
        render json: {
          count: count,
          attention_items: attention_items.map { |attention_item| serialize(attention_item) }
        }
      end
    end

    def create
      title = params[:title].presence
      category = params[:category].presence
      return render json: { error: "Title is required" }, status: :bad_request unless title
      return render json: { error: "Category is required" }, status: :bad_request unless category

      user = User.find_by(id: params[:user_id]) if params[:user_id].present?
      project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
      room = Room.find_by(id: params[:room_id]) if params[:room_id].present?

      if params[:project_id].present? && project.nil?
        return render json: { error: "Project not found" }, status: :not_found
      end

      if params[:room_id].present? && room.nil?
        return render json: { error: "Room not found" }, status: :not_found
      end

      if params[:user_id].present? && user.nil?
        return render json: { error: "User not found" }, status: :not_found
      end

      attention_item = AttentionItem.new(
        title: title,
        category: category,
        meta_text: params[:meta_text],
        due_at: params[:due_at].present? ? Time.zone.parse(params[:due_at].to_s) : nil,
        status: params[:status].presence || "pending",
        overdue: params[:overdue].present? ? ActiveModel::Type::Boolean.new.cast(params[:overdue]) : false,
        user: user,
        project: project,
        room: room,
        source_id: params[:source_id],
        source_type: params[:source_type],
        target_id: params[:target_id],
        target_type: params[:target_type],
        action_label: params[:action_label],
        ai_confirm: params[:ai_confirm].present? ? ActiveModel::Type::Boolean.new.cast(params[:ai_confirm]) : false
      )

      unless attention_item.save
        return render json: { error: attention_item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(attention_item), status: :created
    rescue ArgumentError
      render json: { error: "Invalid date format for due_at" }, status: :unprocessable_entity
    end

    def show
      attention_item = AttentionItem.find_by(id: params[:id])
      return render json: { error: "Attention item not found" }, status: :not_found unless attention_item

      render json: serialize(attention_item)
    end

    def update
      attention_item = AttentionItem.find_by(id: params[:id])
      return render json: { error: "Attention item not found" }, status: :not_found unless attention_item

      if params[:title].present?
        attention_item.title = params[:title]
      end

      if params[:category].present?
        attention_item.category = params[:category]
      end

      if params[:meta_text].present? || params.key?(:meta_text)
        attention_item.meta_text = params[:meta_text]
      end

      if params[:due_at].present? || params.key?(:due_at)
        attention_item.due_at = params[:due_at].present? ? Time.zone.parse(params[:due_at].to_s) : nil
      end

      if params[:status].present?
        attention_item.status = params[:status]
      end

      if params[:overdue].present? || params.key?(:overdue)
        attention_item.overdue = ActiveModel::Type::Boolean.new.cast(params[:overdue])
      end

      if params[:user_id].present? || params.key?(:user_id)
        attention_item.user = params[:user_id].present? ? User.find_by(id: params[:user_id]) : nil
        return render json: { error: "User not found" }, status: :not_found if params[:user_id].present? && attention_item.user.nil?
      end

      if params[:project_id].present? || params.key?(:project_id)
        attention_item.project = params[:project_id].present? ? Project.find_by(id: params[:project_id]) : nil
        return render json: { error: "Project not found" }, status: :not_found if params[:project_id].present? && attention_item.project.nil?
      end

      if params[:room_id].present? || params.key?(:room_id)
        attention_item.room = params[:room_id].present? ? Room.find_by(id: params[:room_id]) : nil
        return render json: { error: "Room not found" }, status: :not_found if params[:room_id].present? && attention_item.room.nil?
      end

      if params[:source_id].present? || params.key?(:source_id)
        attention_item.source_id = params[:source_id]
      end

      if params[:source_type].present? || params.key?(:source_type)
        attention_item.source_type = params[:source_type]
      end

      if params[:target_id].present? || params.key?(:target_id)
        attention_item.target_id = params[:target_id]
      end

      if params[:target_type].present? || params.key?(:target_type)
        attention_item.target_type = params[:target_type]
      end

      if params[:action_label].present? || params.key?(:action_label)
        attention_item.action_label = params[:action_label]
      end

      if params[:ai_confirm].present? || params.key?(:ai_confirm)
        attention_item.ai_confirm = ActiveModel::Type::Boolean.new.cast(params[:ai_confirm])
      end

      unless attention_item.save
        return render json: { error: attention_item.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      render json: serialize(attention_item)
    rescue ArgumentError
      render json: { error: "Invalid date format for due_at" }, status: :unprocessable_entity
    end

    def destroy
      attention_item = AttentionItem.find_by(id: params[:id])
      return render json: { error: "Attention item not found" }, status: :not_found unless attention_item

      attention_item.destroy
      head :no_content
    end

    private

    def build_scope
      scope = AttentionItem.ordered

      if params[:category].present?
        scope = scope.where(category: params[:category])
      end

      if params[:status].present?
        scope = scope.where(status: params[:status])
      end

      if params[:user_id].present?
        scope = scope.where(user_id: params[:user_id])
      end

      if params[:project_id].present?
        scope = scope.where(project_id: params[:project_id])
      end

      if params[:room_id].present?
        scope = scope.where(room_id: params[:room_id])
      end

      if params[:created_at_gt].present?
        begin
          scope = scope.where("created_at > ?", Time.zone.parse(params[:created_at_gt].to_s))
        rescue ArgumentError
          return scope.none
        end
      end

      if params[:created_at_lt].present?
        begin
          scope = scope.where("created_at < ?", Time.zone.parse(params[:created_at_lt].to_s))
        rescue ArgumentError
          return scope.none
        end
      end

      scope
    end

    def serialize(attention_item)
      attention_item.as_json(only: ATTENTION_ITEM_FIELDS)
    end
  end
end
