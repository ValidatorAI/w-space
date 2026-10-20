class McpCallLog < ApplicationRecord
  validates :tool_call_name, presence: true

  scope :errors, -> { where(is_error: true) }
  scope :recent, -> { order(created_at: :desc) }
end
