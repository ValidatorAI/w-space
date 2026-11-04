class WelcomeController < ApplicationController
  def show
    if Current.user.rooms.any?
      redirect_to room_url(last_room_visited)
    elsif Current.user.projects.any?
      redirect_to user_company_home_path(user_id: "me")
    else
      redirect_to user_company_home_path(user_id: "me")
    end
  end
end
