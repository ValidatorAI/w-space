class User < ApplicationRecord
  include Avatar, Bannable, Bot, Mentionable, Role, Transferable

  has_many :project_users, dependent: :delete_all
  has_many :projects, through: :project_users

  has_many :memberships, as: :participant, dependent: :delete_all
  has_many :rooms, through: :memberships

  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, as: :creator, dependent: :destroy

  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

  has_many :boosts, dependent: :destroy, foreign_key: :booster_id
  has_many :searches, dependent: :delete_all

  has_many :sessions, dependent: :destroy
  has_many :bans, dependent: :destroy
  has_many :attention_items, dependent: :nullify
  has_many :resolved_attention_items, class_name: "AttentionItem", foreign_key: :resolved_by_id, dependent: :nullify

  enum :status, %i[ active deactivated banned ], default: :active

  has_secure_password validations: false

  after_create_commit :grant_membership_to_open_rooms

  scope :ordered, -> { order("LOWER(name)") }
  scope :filtered_by, ->(query) { where("name like ?", "%#{query}%") }

  validates :display_name, length: { maximum: 255 }, allow_blank: true
  validates :job_title, length: { maximum: 255 }, allow_blank: true
  validates :timezone,
            length: { maximum: 100 },
            inclusion: { in: ActiveSupport::TimeZone.all.map(&:name), message: "is not a valid timezone" },
            allow_blank: true
  validate :preferences_must_be_object

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ effective_display_name, bio ].compact_blank.join(" – ")
  end

  def effective_display_name
    display_name.presence || name
  end

  def public_mcp_attributes
    attributes.slice(
      "id",
      "name",
      "display_name",
      "job_title",
      "bio",
      "role",
      "status",
      "timezone",
      "created_at",
      "updated_at"
    )
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.delete_all
      push_subscriptions.delete_all
      searches.delete_all
      sessions.delete_all

      update! status: :deactivated, email_address: deactived_email_address
    end
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end

  private
    def preferences_must_be_object
      return if preferences.blank? || preferences.is_a?(Hash)

      errors.add(:preferences, "must be a JSON object")
    end

    def grant_membership_to_open_rooms
      room_ids = Rooms::Open.where(project_id: nil).pluck(:id) +
                 Rooms::Open.where(project_id: projects.select(:id)).pluck(:id)

      Membership.insert_all(
        room_ids.uniq.collect do |room_id|
          { room_id: room_id, participant_type: "User", participant_id: id }
        end
      ) if room_ids.any?
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      ActionCable.server.remote_connections.where(current_user: self).disconnect reconnect: reconnect
    end
end
