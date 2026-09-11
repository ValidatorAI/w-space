class AttentionItemsController < ApplicationController
  before_action :set_attention_item

  def resolve
    @attention_item.resolve!(Current.user)
    OutputEvents::Recorder.record(
      event_type: @attention_item.resolved_event_type,
      event_id: @attention_item.id,
      actor: Current.user,
      target_type: "AttentionItem",
      data: {
        "category" => @attention_item.category,
        "status" => @attention_item.status,
        "title" => @attention_item.title,
        "action_label" => @attention_item.effective_action_label,
        "target_type" => @attention_item.target_type,
        "room_id" => @attention_item.room_id,
        "project_id" => @attention_item.project_id,
        "source_type" => @attention_item.source_type,
        "source_id" => @attention_item.source_id
      }.compact
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_company_home_path(user_id: "me"), notice: "Attention item resolved" }
      format.json { render json: { status: "resolved", id: @attention_item.id } }
    end
  end

  def dismiss
    @attention_item.dismiss!(Current.user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_company_home_path(user_id: "me"), notice: "Attention item dismissed" }
      format.json { render json: { status: "dismissed", id: @attention_item.id } }
    end
  end

  def update
    if params[:status] == "resolved"
      resolve
    elsif params[:status] == "dismissed"
      dismiss
    else
      @attention_item.update!(attention_item_params)
      respond_to do |format|
        format.html { redirect_back fallback_location: user_company_home_path(user_id: "me") }
        format.json { render json: @attention_item }
      end
    end
  end

  private
    def set_attention_item
      @attention_item = AttentionItem.find(params[:id])
    end

    def attention_item_params
      params.require(:attention_item).permit(:title, :meta_text, :action_label, :overdue, :ai_confirm)
    end
end
