class RoomHistoryTopic < ApplicationRecord
  belongs_to :room
  belongs_to :topic

  validates :room, presence: true
  validates :topic, presence: true
  validates :created_date, presence: true
end
