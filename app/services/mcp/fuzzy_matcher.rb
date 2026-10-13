module Mcp
  class FuzzyMatcher
    def self.normalize_text(val)
      return "" if val.nil?
      text = val.to_s.strip.downcase
      text.gsub(/[^a-z0-9]+/, " ").strip
    end

    def self.similarity_score(query, candidate)
      q = normalize_text(query)
      c = normalize_text(candidate)
      return 0.0 if q.empty? || c.empty?
      return 1.0 if q == c
      return 0.95 if c.include?(q) || q.include?(c)

      q_tokens = q.split
      c_tokens = c.split
      union_size = (q_tokens | c_tokens).size
      overlap = union_size > 0 ? ((q_tokens & c_tokens).size.to_f / union_size) : 0.0

      q_pairs = (0..q.length - 2).map { |i| q[i, 2] }
      c_pairs = (0..c.length - 2).map { |i| c[i, 2] }
      pair_score = if q_pairs.any? && c_pairs.any?
                     (2.0 * (q_pairs & c_pairs).size) / (q_pairs.size + c_pairs.size)
                   else
                     0.0
                   end

      [overlap, pair_score].max
    end

    def self.match_project(query)
      return nil if query.blank?
      return Project.find_by(id: query) if query.to_s =~ /\A\d+\z/

      best_record = nil
      best_score = 0.0

      Project.find_each do |project|
        candidates = [project.name]
        candidates << project.slug if project.respond_to?(:slug)
        candidates.compact.each do |c|
          score = similarity_score(query, c)
          if score > best_score
            best_score = score
            best_record = project
          end
        end
      end

      best_score >= 0.4 ? best_record : nil
    end

    def self.match_room(query, project_id: nil)
      return nil if query.blank?
      return Room.find_by(id: query) if query.to_s =~ /\A\d+\z/

      scope = Room.all
      scope = scope.where(project_id: project_id) if project_id.present?

      best_record = nil
      best_score = 0.0

      scope.find_each do |room|
        candidates = [room.name]
        candidates << room.slug if room.respond_to?(:slug)
        candidates.compact.each do |c|
          score = similarity_score(query, c)
          if score > best_score
            best_score = score
            best_record = room
          end
        end
      end

      best_score >= 0.4 ? best_record : nil
    end

    def self.match_user(query, project_id: nil)
      return nil if query.blank?
      return User.find_by(id: query) if query.to_s =~ /\A\d+\z/

      scope = User.all
      best_record = nil
      best_score = 0.0

      scope.find_each do |user|
        candidates = [user.name]
        candidates << user.email_address if user.respond_to?(:email_address)
        candidates << user.effective_display_name if user.respond_to?(:effective_display_name)
        candidates.compact.each do |c|
          score = similarity_score(query, c)
          if score > best_score
            best_score = score
            best_record = user
          end
        end
      end

      best_score >= 0.4 ? best_record : nil
    end

    def self.match_bot(query)
      return nil if query.blank?
      return User.bot.find_by(id: query) if query.to_s =~ /\A\d+\z/

      best_record = nil
      best_score = 0.0

      User.bot.find_each do |bot|
        candidates = [bot.name]
        candidates << bot.display_name if bot.respond_to?(:display_name)
        candidates.compact.each do |c|
          score = similarity_score(query, c)
          if score > best_score
            best_score = score
            best_record = bot
          end
        end
      end

      best_score >= 0.4 ? best_record : nil
    end
  end
end
