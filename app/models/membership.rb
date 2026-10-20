class Membership < ApplicationRecord
  include Connectable

  belongs_to :room
  belongs_to :participant, polymorphic: true

  after_destroy_commit :reset_participant_connections

  enum :involvement, %w[ invisible nothing mentions everything ].index_by(&:itself), prefix: :involved_in

  scope :with_ordered_room, -> { includes(:room).joins(:room).order("LOWER(rooms.name)") }
  scope :without_direct_rooms, -> { joins(:room).where.not(room: { type: "Rooms::Direct" }) }

  scope :visible, -> { where.not(involvement: :invisible) }
  scope :unread,  -> { where.not(unread_at: nil) }

  # Scopes for filtering by participant type
  scope :users, -> { where(participant_type: "User") }

  def read
    update!(unread_at: nil)
  end

  def unread?
    unread_at.present?
  end

  # Backwards compatibility helpers
  def user
    participant if participant_type == "User"
  end

  private

  def reset_participant_connections
    participant.reset_remote_connections if participant.respond_to?(:reset_remote_connections)
  end
end
