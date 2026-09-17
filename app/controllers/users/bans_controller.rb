class Users::BansController < ApplicationController
  before_action :ensure_can_administer
  before_action :set_user

  def create
    @user.ban
    OutputEvents::Recorder.record(
      event_type: "user_banned",
      event_id: @user.id,
      actor: Current.user,
      target_type: "User",
      data: {}
    )
    redirect_to @user
  end

  def destroy
    @user.unban
    OutputEvents::Recorder.record(
      event_type: "user_unbanned",
      event_id: @user.id,
      actor: Current.user,
      target_type: "User",
      data: {}
    )
    redirect_to @user
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end
end
