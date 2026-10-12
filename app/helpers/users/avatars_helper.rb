require "zlib"

module Users::AvatarsHelper
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ]

  def avatar_background_color(user)
    AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
  end

  def avatar_tag(user, **options)
    target = user == Current.user ? user_settings_path : user_path(user)

    link_to target, title: user.title, class: "btn avatar", data: { turbo_frame: "_top" } do
      image_tag fresh_user_avatar_path(user), aria: { hidden: "true" }, size: 48, **options
    end
  end

  # Polymorphic avatar tag that handles both User and Agent
  def participant_avatar_tag(participant, **options)
    case participant
    when User
      avatar_tag(participant, **options)
    when Agent
      agent_avatar_tag(participant, **options)
    else
      content_tag :span, "?", class: "btn avatar avatar--unknown", title: "Unknown"
    end
  end
end
