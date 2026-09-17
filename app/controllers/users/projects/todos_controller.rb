class Users::Projects::TodosController < ApplicationController
  before_action :set_project
  before_action :set_todo

  def toggle
    @todo.toggle_completed!
    OutputEvents::Recorder.record(
      event_type: @todo.completed? ? "project_todo_completed" : "project_todo_reopened",
      event_id: @todo.id,
      actor: Current.user,
      target_type: "ProjectTodo",
      data: { "project_id" => @project.id }
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@todo),
          partial: "users/projects/status/todo_item",
          locals: { todo: @todo, project: @project }
        )
      end
      format.html { redirect_to user_company_project_status_path(user_id: "me", id: @project.id) }
    end
  end

  private
    def set_project
      @project = Current.user.projects.find_by(id: params[:project_id])
      raise ActiveRecord::RecordNotFound if @project.blank?
    end

    def set_todo
      @todo = @project.todos.find(params[:id])
    end
end
