class Rooms::Project < Room
  belongs_to :project, optional: false

  validates :project_id, uniqueness: { message: "already has a project room" }

  def default_involvement
    "mentions"
  end

  def auto_join_user(user)
    memberships.grant_to(user)
  end
end
