class FirstRun
  ACCOUNT_NAME = "W space"
  FIRST_ROOM_NAME = "All Talk"
  META_ROOM_NAME = "Meta Events"

  DEFAULT_ADMIN_NAME = ENV.fetch("DEFAULT_ADMIN_NAME", "Admin").presence || "Admin"
  DEFAULT_ADMIN_EMAIL = ENV.fetch("DEFAULT_ADMIN_EMAIL", "admin@pwrwork.local").presence || "admin@pwrwork.local"
  DEFAULT_ADMIN_PASSWORD = ENV.fetch("DEFAULT_ADMIN_PASSWORD", "pwrpassword").presence || "pwrpassword"

  HUMAN_OVERSEER_NAME = DEFAULT_ADMIN_NAME
  HUMAN_OVERSEER_EMAIL = DEFAULT_ADMIN_EMAIL
  HUMAN_OVERSEER_PASSWORD = DEFAULT_ADMIN_PASSWORD
  COMPANY_BOT_NAME = "Ask about company"
  COMPANY_BOT_EMAIL = "ask-about-company@space.local"

  class << self
    # Auto-setup without user input - creates the default admin automatically
    def setup!
      return if Account.any?

      ActiveRecord::Base.transaction do
        account = Account.create!(name: ACCOUNT_NAME)

        overseer = User.create!(
          name: HUMAN_OVERSEER_NAME,
          email_address: HUMAN_OVERSEER_EMAIL,
          role: :administrator,
          password: HUMAN_OVERSEER_PASSWORD,
          display_name: HUMAN_OVERSEER_NAME
        )

        ensure_company_bot!
        overseer
      end
    end

    def ensure_company_bot!
      User.find_by(email_address: COMPANY_BOT_EMAIL) ||
        User.create_bot!(
          name: COMPANY_BOT_NAME,
          display_name: COMPANY_BOT_NAME,
          email_address: COMPANY_BOT_EMAIL
        )
    end

    def human_overseer
      overseer = User.find_by(email_address: HUMAN_OVERSEER_EMAIL) || setup!
      ensure_overseer_in_all_rooms(overseer) if overseer
      overseer
    end

    def ensure_overseer_in_all_rooms(overseer)
      Room.find_each do |room|
        # Check specifically for User membership (not Agent with same id)
        next if Membership.exists?(
          room_id: room.id,
          participant_type: "User",
          participant_id: overseer.id
        )

        Membership.create(
          room_id: room.id,
          participant_type: "User",
          participant_id: overseer.id,
          involvement: room.default_involvement
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
        # Already exists, ignore
      end
    end

    # Legacy method for compatibility
    def create!(user_params)
      return setup! if Account.none? && User.none?

      Account.transaction do
        account = Account.find_or_create_by!(singleton_guard: 0) { |record| record.name = ACCOUNT_NAME }
        user = User.create!(
          name: user_params[:name],
          email_address: user_params[:email_address],
          password: user_params[:password],
          display_name: user_params[:display_name].presence || user_params[:name],
          role: :administrator
        )

        user
      end
    end
  end
end
