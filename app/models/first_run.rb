class FirstRun
  ACCOUNT_NAME = "W space"
  FIRST_ROOM_NAME = "All Talk"
  META_ROOM_NAME = "Meta Events"
  HUMAN_OVERSEER_NAME = "Human Overseer"
  HUMAN_OVERSEER_EMAIL = "overseer@bonfire.local"
  HUMAN_OVERSEER_PASSWORD = "PavelLab"
  COMPANY_BOT_NAME = "Ask about company"
  COMPANY_BOT_EMAIL = "ask-about-company@bonfire.local"

  class << self
    # Auto-setup without user input - creates Human Overseer automatically
    def setup!
      return if Account.any?

      ActiveRecord::Base.transaction do
        account = Account.create!(name: ACCOUNT_NAME)

        # Create Human Overseer - the single human user
        overseer = User.create!(
          name: HUMAN_OVERSEER_NAME,
          email_address: HUMAN_OVERSEER_EMAIL,
          role: :administrator,
          password: HUMAN_OVERSEER_PASSWORD,
          display_name: HUMAN_OVERSEER_NAME
        )

        Rooms::Open.create_for({ name: FIRST_ROOM_NAME, creator: overseer }, users: [overseer])
        ensure_company_bot!
        account
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

        Rooms::Open.find_or_create_by!(name: FIRST_ROOM_NAME, creator: user) do |room|
          room.private = false
          room.type = "Rooms::Open"
        end

        user
      end
    end
  end
end
