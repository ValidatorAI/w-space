module User::Bot
  extend ActiveSupport::Concern

  included do
    scope :active_bots, -> { active.where(role: :bot) }
    scope :without_bots, -> { where.not(role: :bot) }
  end

  module ClassMethods
    def create_bot!(attributes)
      attributes = attributes.to_h.with_indifferent_access
      attributes[:display_name] = attributes[:display_name].presence || attributes[:name]

      User.create!(**attributes, bot_token: generate_bot_token, role: :bot)
    end

    def authenticate_bot(bot_key)
      bot_id, bot_token = bot_key.split("-")
      active_bots.find_by(id: bot_id, bot_token: bot_token)
    end

    def generate_bot_token
      SecureRandom.alphanumeric(12)
    end
  end

  def update_bot!(attributes)
    update!(attributes)
  end

  def bot_key
    "#{id}-#{bot_token}"
  end

  def reset_bot_key
    update! bot_token: self.class.generate_bot_token
  end
end
