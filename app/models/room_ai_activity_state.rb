class RoomAiActivityState < ApplicationRecord
  belongs_to :room, optional: true

  enum :state, { thinking: 0, typing: 1, done: 2 }, default: :thinking

  validates :state, presence: true

  scope :active, -> { where(state: [ :thinking, :typing ]) }
  scope :recent, -> { order(updated_at: :desc) }
end