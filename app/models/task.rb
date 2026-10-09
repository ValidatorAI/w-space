class Task < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :room, optional: true
  belongs_to :parent_task, class_name: "Task", optional: true, foreign_key: :parent_task_id, inverse_of: :child_tasks
  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :nullify, inverse_of: :parent_task
  belongs_to :grand_parent_task, class_name: "Task", optional: true, foreign_key: :grand_parent_id, inverse_of: :grand_child_tasks
  has_many :grand_child_tasks, class_name: "Task", foreign_key: :grand_parent_id, dependent: :nullify, inverse_of: :grand_parent_task

  validates :description, presence: true
  validates :importance, :level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :token_used, numericality: { only_integer: true, allow_nil: true }
  validates :usd_used, numericality: true, allow_nil: true
  validates :usd_usage, :usd_budget, numericality: true, allow_nil: true

  def apply_task_cost!(new_token_used, new_usd_used)
    old_token_used = token_used.to_i
    old_usd_used = usd_used.to_f
    next_token_used = new_token_used.nil? ? old_token_used : new_token_used.to_i
    next_usd_used = new_usd_used.nil? ? old_usd_used : new_usd_used.to_f

    token_delta = next_token_used - old_token_used
    usd_delta = next_usd_used - old_usd_used

    update!(token_used: next_token_used, usd_used: next_usd_used)

    parent = parent_task
    while parent.present?
      parent.update_columns(
        token_used: (parent.token_used.to_i + token_delta),
        usd_used: (parent.usd_used.to_f + usd_delta)
      )
      parent = parent.parent_task
    end
  end
end
