class Message < ApplicationRecord
  include Attachment, Broadcasts, Mentionee, Pagination, Searchable

  belongs_to :room, touch: true
  belongs_to :creator, polymorphic: true, default: -> { Current.user }

  has_many :boosts, dependent: :destroy
  has_one :approval_request, dependent: :destroy

  has_rich_text :body

  validate :body_or_attachment_present

  before_create -> { self.client_message_id ||= Random.uuid } # Bots don't care
  after_create_commit -> { room.receive(self) }

  scope :ordered, -> { order(:created_at) }
  scope :with_creator, -> { preload(:creator) }
  scope :with_attachment_details, -> {
    with_rich_text_body_and_embeds
    with_attached_attachment
      .includes(attachment_blob: :variant_records)
  }
  scope :with_boosts, -> { includes(boosts: :booster) }

  # Helper methods for creator type checking
  def from_user?
    creator_type == "User"
  end

  def from_system?
    system?
  end

  def plain_text_body
    body.to_plain_text.presence || attachment&.filename&.to_s || ""
  end

  def to_key
    [ client_message_id ]
  end

  def content_type
    case
    when attachment?    then "attachment"
    when sound.present? then "sound"
    else                     "text"
    end.inquiry
  end

  def sound
    plain_text_body.match(/\A\/play (?<name>\w+)\z/) do |match|
      Sound.find_by_name match[:name]
    end
  end

  private
    def body_or_attachment_present
      return if attachment?
      return if body.to_plain_text.present?

      errors.add(:body, :blank)
    end
end
