module UsersHelper
  def button_to_direct_room_with(user)
    button_to rooms_directs_path(user_ids: [ user.id ]), class: "btn btn--reversed full-width txt-large" do
      image_tag("messages.svg", aria: { hidden: "true" }, class: "btn__icon")
    end
  end
end
