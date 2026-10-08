class MessageAnalysis < ApplicationRecord
  self.table_name = "message_analysis"

  belongs_to :message

  validates :message, presence: true
  validates :importance_level, presence: true, inclusion: { in: 1..5 }
  validates :message_content_summary, presence: true
  validates :message_type, presence: true
  validates :is_a_response, inclusion: { in: [true, false] }
end
