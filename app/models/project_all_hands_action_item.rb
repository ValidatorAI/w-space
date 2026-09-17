class ProjectAllHandsActionItem < ApplicationRecord
  belongs_to :project

  validates :project, presence: true
  validates :title, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :pending, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }

  def pending?
    !completed?
  end

  def toggle_completed!
    update!(
      completed: !completed?,
      completed_at: (!completed? ? Time.current : nil)
    )
  end
end
