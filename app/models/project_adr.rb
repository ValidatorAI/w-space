class ProjectAdr < ApplicationRecord
  belongs_to :project
  has_many :decision_rooms, dependent: :destroy
  has_many :rooms, through: :decision_rooms

  validates :identifier, presence: true
  validates :title, presence: true
  validates :status, inclusion: { in: %w[accepted proposed deprecated superseded] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, decision_date: :desc, created_at: :desc) }

  def formatted_date
    decision_date&.strftime("%Y-%m-%d") || created_at.strftime("%Y-%m-%d")
  end
end
