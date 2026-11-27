module MessagePostingAuthorization
  module_function

  def allowed?(room:, actor:)
    return false if actor.blank?
    room.present? && room.member?(actor)
  end

  def forbidden_response
    { error: "Not allowed" }
  end
end
