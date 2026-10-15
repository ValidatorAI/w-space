class ProjectKnowledgeItem < ApplicationRecord
  belongs_to :project
  has_many :room_evidences, dependent: :destroy
  has_many :rooms, through: :room_evidences

  validates :title, presence: true
  validates :description, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :for_badge, ->(badge) { where(badge: badge) }

  def display_badge
    badge.presence || "Insight"
  end

  def summary_text
    description.to_s.strip.gsub(/\s+/, " ")
  end

  def room_summary_for(room)
    room_evidences.where(room: room).order(:created_at).last&.summary.presence || summary_text.presence || "Project source"
  end
end
