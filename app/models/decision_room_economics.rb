class DecisionRoomEconomics < ApplicationRecord
  belongs_to :decision_room
  has_one :room, through: :decision_room
  has_one :project_adr, through: :decision_room

  validates :decision_room, presence: true
  validates :decision_room_id, uniqueness: true
  validates :research_effort, :guided_build_effort, :expected_learning_value,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :risk_level, inclusion: { in: %w[low medium high critical], allow_blank: true }

  def risk_label
    case risk_level.to_s.downcase
    when "low" then "Low risk"
    when "medium" then "Medium risk"
    when "high" then "High risk"
    when "critical" then "Critical risk"
    else
      "Unspecified risk"
    end
  end
end
