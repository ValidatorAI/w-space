class OutputEventDispatchGroup < ApplicationRecord
  STATUSES = %w[pending dispatched duplicate_merged failed deferred_merge_window].freeze

  belongs_to :lead_output_event, class_name: "OutputEvent", optional: true

  validates :dedupe_key, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :dispatched, -> { where(status: "dispatched") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }
end
