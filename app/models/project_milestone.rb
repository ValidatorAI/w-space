class ProjectMilestone < ApplicationRecord
  belongs_to :project

  validates :title, presence: true
  validates :position, numericality: { only_integer: true }, allow_nil: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
end
