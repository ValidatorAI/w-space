class Project < ApplicationRecord
  has_many :agents, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :file_reservations, dependent: :destroy
  has_many :project_users, dependent: :delete_all
  has_many :users, through: :project_users
  has_many :attention_items, dependent: :nullify
  has_many :bottlenecks, class_name: "ProjectBottleneck", dependent: :destroy
  has_many :todos, class_name: "ProjectTodo", dependent: :destroy
  has_many :knowledge_items, class_name: "ProjectKnowledgeItem", dependent: :destroy
  has_many :project_all_hands_takeaways, class_name: "ProjectAllHandsTakeaway", dependent: :destroy
  has_many :project_all_hands_action_items, class_name: "ProjectAllHandsActionItem", dependent: :destroy
  has_many :project_all_hands_decisions, class_name: "ProjectAllHandsDecision", dependent: :destroy
  has_many :obsidian_notes, class_name: "ProjectObsidianNote", dependent: :destroy
  has_many :external_assets, class_name: "ProjectExternalAsset", dependent: :destroy
  has_many :adrs, class_name: "ProjectAdr", dependent: :destroy
  has_many :knowledge_activities, class_name: "ProjectKnowledgeActivity", dependent: :destroy
  has_many :directory_items, class_name: "ProjectDirectoryItem", dependent: :destroy
  has_many :project_milestones, dependent: :destroy
  has_many :milestones, class_name: "ProjectMilestone", dependent: :destroy

  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "must be lowercase alphanumeric with dashes" }
  validates :path, presence: true, uniqueness: true
  validates :name, length: { maximum: 255 }, allow_blank: true
  validates :short_code,
            length: { maximum: 64 },
            format: { with: /\A[A-Za-z0-9_-]+\z/, message: "must use only letters, numbers, underscores, or dashes" },
            uniqueness: true,
            allow_blank: true
  validates :budget_total, :budget_spent, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :generate_slug_from_path, on: :create, if: -> { slug.blank? }
  before_validation :normalize_short_code
  after_create_commit :announce_creation

  def self.find_or_create_for_path(path)
    find_by(path: path) || create!(path: path)
  end

  def project_room
    rooms.find_by(type: "Rooms::Project")
  end

  def ensure_project_room!
    project_room || rooms.create!(
      type: "Rooms::Project",
      name: slug,
      private: private,
      creator: default_room_creator
    )
  end

  def display_name
    name.presence || slug
  end

  def current_phase_name
    current_phase.presence || "Phase 1: Project Setup"
  end

  def progress_percent_value
    progress_percent || 0
  end

  def recently_completed_text
    recently_completed.presence
  end

  private

  def generate_slug_from_path
    self.slug = File.basename(path).parameterize
  end

  def normalize_short_code
    self.short_code = short_code.presence&.upcase
  end

  def default_room_creator
    User.where(role: :administrator).first || User.first
  end

  def announce_creation
    SystemMessage.project_created(project: self)
  end
end
