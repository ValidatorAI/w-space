class ProjectKnowledgeItem < ApplicationRecord
  belongs_to :project

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
end
