class Users::Projects::ActionItemsController < ApplicationController
  before_action :set_project
  before_action :set_action_item

  def toggle
    @action_item.toggle_completed!
    @action_items = @project.project_all_hands_action_items.active.ordered
    OutputEvents::Recorder.record(
      event_type: @action_item.completed? ? "all_hands_action_item_completed" : "all_hands_action_item_reopened",
      event_id: @action_item.id,
      actor: Current.user,
      target_type: "ProjectAllHandsActionItem",
      data: { "project_id" => @project.id }
    )

    broadcast_action_items_update

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "all_hands_action_items_card",
          partial: "users/projects/all_hands/action_items_card",
          locals: { action_items: @action_items, project: @project }
        )
      end
      format.html { redirect_to user_company_project_all_hands_path(user_id: "me", id: @project.id) }
    end
  end

  private
    def broadcast_action_items_update
      Turbo::StreamsChannel.broadcast_replace_to(
        @project, :all_hands,
        target: "all_hands_action_items_card",
        partial: "users/projects/all_hands/action_items_card",
        locals: { action_items: @action_items, project: @project }
      )
    end

    def set_project
      @project = Current.user.projects.find_by(id: params[:project_id])
      raise ActiveRecord::RecordNotFound if @project.blank?
    end

    def set_action_item
      @action_item = @project.project_all_hands_action_items.find_by!(id: params[:id])
    end
end
