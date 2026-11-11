module AiProfiles
  class Destroy
    def self.call(profile:, actor: nil)
      previous_bot_name = profile.bot_name

      ActiveRecord::Base.transaction do
        if profile.bot?
          profile.bot = false
          AiProfiles::BotSync.call(profile: profile, previous_bot: true, previous_bot_name: previous_bot_name)
        end

        profile.destroy!
      end

      profile
    end
  end
end
