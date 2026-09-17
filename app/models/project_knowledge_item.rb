class ProjectKnowledgeItem < ApplicationRecord
  belongs_to :project

  validates :title, presence: true
  validates :description, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :for_badge, ->(badge) { where(badge: badge) }
end
