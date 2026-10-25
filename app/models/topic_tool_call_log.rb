class TopicToolCallLog < ApplicationRecord
  belongs_to :topic, optional: true
  belongs_to :room, optional: true
  belongs_to :project, optional: true

  validates :used_tool_name, presence: true
  validates :created_date, presence: true

  scope :ordered, -> { order(created_date: :desc, id: :desc) }

  scope :between_dates, ->(start_date, end_date) {
    scope = all
    scope = scope.where("created_date >= ?", start_date.beginning_of_day) if start_date.present?
    scope = scope.where("created_date <= ?", end_date.end_of_day) if end_date.present?
    scope
  }
end
