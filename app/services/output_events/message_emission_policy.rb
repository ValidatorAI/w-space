module OutputEvents
  class MessageEmissionPolicy
    class << self
      def allowed?(message:)
        return false if bot_user_sender?(message)
        return true unless message.room.direct?

        message.from_user? && message.room.users.active_bots.exists?
      end

      private
        def bot_user_sender?(message)
          message.from_user? && message.creator&.bot?
        end
    end
  end
end