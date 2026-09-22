module AiProfiles
  class BotSync
    def self.call(profile:, previous_bot:, previous_bot_name: nil)
      new(profile: profile, previous_bot: previous_bot, previous_bot_name: previous_bot_name).call
    end

    def initialize(profile:, previous_bot:, previous_bot_name: nil)
      @profile = profile
      @previous_bot = ActiveModel::Type::Boolean.new.cast(previous_bot)
      @previous_bot_name = previous_bot_name.to_s.strip.presence
    end

    def call
      profile.bot? ? enable_bot! : disable_bots!
    end

    private

    attr_reader :profile, :previous_bot, :previous_bot_name

    def enable_bot!
      desired_name = profile.bot_name.to_s.strip.presence || inferred_bot_name
      profile.update!(bot_name: desired_name) if profile.bot_name.to_s.strip != desired_name

      candidate = find_candidate_bot(desired_name)
      if candidate
        reactivate_or_update_bot!(candidate, desired_name)
      else
        User.create_bot!(name: desired_name, display_name: desired_name)
      end
    end

    def disable_bots!
      names = matching_names
      return if names.empty?

      User.where(role: :bot, status: :active)
          .where("name IN (:names) OR display_name IN (:names)", names: names)
          .find_each(&:deactivate)
    end

    def find_candidate_bot(desired_name)
      exact_name_candidates = bots_matching_name(desired_name)
      return preferred_candidate(exact_name_candidates) if exact_name_candidates.any?

      if previous_bot_name.present? && previous_bot_name != desired_name
        previous_name_candidates = bots_matching_name(previous_bot_name)
        return preferred_candidate(previous_name_candidates) if previous_name_candidates.any?
      end

      nil
    end

    def preferred_candidate(candidates)
      active_match = candidates.find(&:active?)
      return active_match if active_match

      candidates.max_by(&:updated_at)
    end

    def reactivate_or_update_bot!(bot_user, desired_name)
      attributes = {
        name: desired_name,
        display_name: desired_name
      }
      attributes[:status] = :active if bot_user.deactivated?

      bot_user.update!(attributes)
    end

    def bots_matching_name(name)
      return [] if name.blank?

      User.where(role: :bot)
          .where("name = :name OR display_name = :name", name: name)
          .order(updated_at: :desc)
          .to_a
    end

    def matching_names
      [
        profile.bot_name.to_s.strip.presence,
        previous_bot_name,
        inferred_bot_name
      ].compact.uniq
    end

    def inferred_bot_name
      profile.profile_name.to_s.tr("_-", " ").split.map(&:capitalize).join(" ")
    end
  end
end
