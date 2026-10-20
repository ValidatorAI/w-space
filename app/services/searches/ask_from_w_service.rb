module Searches
  class AskFromWService
    def initialize(user:, query:)
      @user = user
      @query = query.to_s.strip
    end

    def call
      return nil if @query.blank?

      bot = find_bot
      raise ActiveRecord::RecordNotFound, "Ask From W bot not found" if bot.nil?

      room = Rooms::Direct.find_or_create_for([@user, bot])
      room.messages.create!(
        body: "Search: #{@query}",
        creator: @user,
        client_message_id: SecureRandom.uuid
      )

      room
    end

    private
      def find_bot
        User.active_bots.find_by(name: "Ask From W") ||
          User.active_bots.find_by(name: "Ask from W") ||
          User.active_bots.order(:created_at).first
      end
  end
end
