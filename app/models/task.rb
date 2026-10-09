class Task < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :room, optional: true
  belongs_to :parent_task, class_name: "Task", optional: true, foreign_key: :parent_task_id, inverse_of: :child_tasks
  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :nullify, inverse_of: :parent_task
  belongs_to :grand_parent_task, class_name: "Task", optional: true, foreign_key: :grand_parent_id, inverse_of: :grand_child_tasks
  has_many :grand_child_tasks, class_name: "Task", foreign_key: :grand_parent_id, dependent: :nullify, inverse_of: :grand_parent_task

  validates :description, presence: true
  validates :importance, :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :usd_usage, :usd_budget, numericality: true, allow_nil: true
end
