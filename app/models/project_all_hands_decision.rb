class ProjectAllHandsDecision < ApplicationRecord
  belongs_to :project

  validates :project, presence: true
  validates :title, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
