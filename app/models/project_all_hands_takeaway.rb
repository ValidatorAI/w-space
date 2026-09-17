class ProjectAllHandsTakeaway < ApplicationRecord
  belongs_to :project

  validates :project, presence: true
  validates :category, presence: true
  validates :content, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
