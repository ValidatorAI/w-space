class AttentionItemsController < ApplicationController
  before_action :set_attention_item

  def resolve
    @attention_item.resolve!(Current.user)

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
