class RoomHistoryTopic < ApplicationRecord
  belongs_to :room

  validates :room, presence: true
  validates :created_date, presence: true
end
