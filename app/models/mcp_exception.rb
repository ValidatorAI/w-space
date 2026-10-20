class McpException < ApplicationRecord
  validates :tool_call_name, presence: true
  validates :exception_class, presence: true
  validates :error_message, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
