class AllHandsController < ApplicationController
  before_action :set_meeting, only: :show

  def show
    if params[:role].to_s == "moderator"
      @target_url = @meeting.moderator_join_url.presence || user_company_project_all_hands_path(user_id: "me", id: @meeting.project_id)
    else
      @target_url = @meeting.member_join_url(Current.user&.effective_display_name || "Guest").presence || user_company_project_all_hands_path(user_id: "me", id: @meeting.project_id)
    end

    render :show
  end

  def create
    project = Project.find(params[:project_id])
    title = params.dig(:project_all_hands_meeting, :title).to_s.strip
    return redirect_to user_company_project_all_hands_path(user_id: "me", id: project.id), alert: "Meeting name is required." if title.blank?

    meeting = project.project_all_hands_meetings.create!(title: title)
    meeting.create_in_big_blue_button!

    redirect_to meeting_path(id: meeting.id, role: "moderator"), notice: "Meeting started"
  rescue ActiveRecord::RecordNotFound
    redirect_to user_company_project_all_hands_path(user_id: "me", id: params[:project_id]), alert: "Project not found."
  rescue StandardError => e
    Rails.logger.error("BBB meeting creation failed: #{e.class}: #{e.message}")
    redirect_to user_company_project_all_hands_path(user_id: "me", id: project.id), alert: "Unable to create the meeting right now."
  end

  private
    def set_meeting
      @meeting = ProjectAllHandsMeeting.find(params[:id])
    end
end
