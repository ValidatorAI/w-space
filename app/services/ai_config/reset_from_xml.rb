module AiConfig
  class ResetFromXml
    ENTITY_NAMES = %w[
      tools
      skills
      mcps
      ai_profiles
      ai_profile_tools
      ai_profile_skills
      ai_profile_mcps
    ].freeze

    def self.call(source_path: XmlLoader::SOURCE_PATH)
      new(source_path: source_path).call
    end

    def initialize(source_path: XmlLoader::SOURCE_PATH)
      @source_path = source_path
      @summary = ENTITY_NAMES.index_with { empty_counters }
    end

    def call
      payload = XmlLoader.new(source_path: source_path).load

      ActiveRecord::Base.transaction do
        sync_tools(payload.fetch(:tools))
        sync_skills(payload.fetch(:skills))
        sync_mcps(payload.fetch(:mcps))
        sync_profiles(payload.fetch(:profiles))
        sync_profile_tools(payload.fetch(:profiles))
        sync_profile_skills(payload.fetch(:profiles))
        sync_profile_mcps(payload.fetch(:profiles))
      end

      summary
    end

    private

    attr_reader :source_path, :summary

    def empty_counters
      {
        "created" => 0,
        "updated" => 0,
        "deleted" => 0
      }
    end

    def sync_tools(rows)
      desired_names = rows.map { |row| row.fetch(:name) }
      existing_by_name = Tool.where(name: desired_names).index_by(&:name)

      rows.each do |attributes|
        tool = existing_by_name[attributes.fetch(:name)] || Tool.new(name: attributes.fetch(:name))
        created = tool.new_record?

        tool.assign_attributes(active: attributes.fetch(:active))
        persist_record(tool, entity: "tools", created: created)
      end

      Tool.where.not(name: desired_names).find_each do |tool|
        tool.destroy!
        tick("tools", "deleted")
      end
    end

    def sync_skills(rows)
      desired_names = rows.map { |row| row.fetch(:name) }
      existing_by_name = Skill.where(name: desired_names).index_by(&:name)

      rows.each do |attributes|
        skill = existing_by_name[attributes.fetch(:name)] || Skill.new(name: attributes.fetch(:name))
        created = skill.new_record?

        skill.assign_attributes(
          category: attributes.fetch(:category),
          description: attributes.fetch(:description),
          skill_text: attributes.fetch(:skill_text),
          add_by_default: attributes.fetch(:add_by_default)
        )

        persist_record(skill, entity: "skills", created: created)
      end

      Skill.where.not(name: desired_names).find_each do |skill|
        skill.destroy!
        tick("skills", "deleted")
      end
    end

    def sync_mcps(rows)
      desired_names = rows.map { |row| row.fetch(:name) }
      existing_by_name = Mcp::Server.where(name: desired_names).index_by(&:name)

      rows.each do |attributes|
        mcp = existing_by_name[attributes.fetch(:name)] || Mcp::Server.new(name: attributes.fetch(:name))
        created = mcp.new_record?

        mcp.assign_attributes(
          transport: attributes.fetch(:transport),
          url: attributes.fetch(:url),
          authentication: attributes.fetch(:authentication),
          bearer_token: attributes.fetch(:bearer_token),
          status: attributes.fetch(:status),
          command: attributes.fetch(:command),
          args: attributes.fetch(:args),
          environment: attributes.fetch(:environment)
        )

        persist_record(mcp, entity: "mcps", created: created)
      end

      Mcp::Server.where.not(name: desired_names).find_each do |mcp|
        mcp.destroy!
        tick("mcps", "deleted")
      end
    end

    def sync_profiles(rows)
      desired_names = rows.map { |row| row.fetch(:profile_name) }
      existing_by_name = AiProfile.where(profile_name: desired_names).index_by(&:profile_name)

      rows.each do |attributes|
        profile = existing_by_name[attributes.fetch(:profile_name)] || AiProfile.new(profile_name: attributes.fetch(:profile_name))
        created = profile.new_record?
        previous_bot = profile.bot
        previous_bot_name = profile.bot_name

        assign_profile_attributes(profile, attributes)

        next unless created || profile.changed?

        profile.save!

        if created
          AiProfiles::BotSync.call(profile: profile, previous_bot: false, previous_bot_name: nil)
          tick("ai_profiles", "created")
        else
          AiProfiles::BotSync.call(profile: profile, previous_bot: previous_bot, previous_bot_name: previous_bot_name)
          tick("ai_profiles", "updated")
        end
      end

      AiProfile.where.not(profile_name: desired_names).find_each do |profile|
        previous_bot_name = profile.bot_name

        if profile.bot?
          profile.bot = false
          AiProfiles::BotSync.call(profile: profile, previous_bot: true, previous_bot_name: previous_bot_name)
        end

        profile.destroy!
        tick("ai_profiles", "deleted")
      end
    end

    def sync_profile_tools(profile_rows)
      tool_ids_by_name = Tool.pluck(:name, :id).to_h
      profiles_by_name = profiles_by_name(profile_rows)

      profile_rows.each do |profile_row|
        profile = profiles_by_name.fetch(profile_row.fetch(:profile_name))
        desired_ids = profile_row.fetch(:tools).map { |name| tool_ids_by_name.fetch(name) }.uniq

        sync_join_rows(
          scope: profile.ai_profile_tools,
          desired_ids: desired_ids,
          id_column: :tool_id,
          state_column: :enabled,
          state_value: true,
          entity: "ai_profile_tools"
        )
      end
    end

    def sync_profile_skills(profile_rows)
      skill_ids_by_name = Skill.pluck(:name, :id).to_h
      profiles_by_name = profiles_by_name(profile_rows)

      profile_rows.each do |profile_row|
        profile = profiles_by_name.fetch(profile_row.fetch(:profile_name))
        desired_ids = profile_row.fetch(:skills).map { |name| skill_ids_by_name.fetch(name) }.uniq

        sync_join_rows(
          scope: profile.ai_profile_skills,
          desired_ids: desired_ids,
          id_column: :skill_id,
          state_column: :enabled,
          state_value: true,
          entity: "ai_profile_skills"
        )
      end
    end

    def sync_profile_mcps(profile_rows)
      mcp_ids_by_name = Mcp::Server.pluck(:name, :id).to_h
      profiles_by_name = profiles_by_name(profile_rows)

      profile_rows.each do |profile_row|
        profile = profiles_by_name.fetch(profile_row.fetch(:profile_name))
        desired_ids = profile_row.fetch(:mcps).map { |name| mcp_ids_by_name.fetch(name) }.uniq

        sync_join_rows(
          scope: profile.ai_profile_mcps,
          desired_ids: desired_ids,
          id_column: :mcp_id,
          state_column: :active,
          state_value: true,
          entity: "ai_profile_mcps"
        )
      end
    end

    def sync_join_rows(scope:, desired_ids:, id_column:, state_column:, state_value:, entity:)
      existing_by_id = scope.index_by { |row| row.public_send(id_column) }

      desired_ids.each do |target_id|
        row = existing_by_id[target_id] || scope.build(id_column => target_id)
        created = row.new_record?

        row.public_send("#{state_column}=", state_value)

        next unless created || row.changed?

        row.save!
        tick(entity, created ? "created" : "updated")
      end

      extra_scope = desired_ids.empty? ? scope : scope.where.not(id_column => desired_ids)
      extra_scope.find_each do |row|
        row.destroy!
        tick(entity, "deleted")
      end
    end

    def persist_record(record, entity:, created:)
      return unless created || record.changed?

      record.save!
      tick(entity, created ? "created" : "updated")
    end

    def assign_profile_attributes(profile, attributes)
      profile.assign_attributes(
        soul: attributes.fetch(:soul),
        bot: attributes.fetch(:bot),
        bot_name: attributes.fetch(:bot_name),
        editable: attributes.fetch(:editable),
        tool_sets_editable: attributes.fetch(:tool_sets_editable),
        max_line_sessions: attributes.fetch(:max_line_sessions),
        max_concurrent_sessions: attributes.fetch(:max_concurrent_sessions),
        auto_decompose_per_tick: attributes.fetch(:auto_decompose_per_tick),
        max_in_progress_per_profile: attributes.fetch(:max_in_progress_per_profile),
        main_model: attributes.fetch(:main_model),
        fallback_model: attributes.fetch(:fallback_model),
        cloned_from: attributes.fetch(:cloned_from)
      )

      if profile.bot?
        profile.bot_name = profile.bot_name.to_s.strip.presence || humanized_bot_name(profile.profile_name)
      else
        profile.bot_name = nil
      end
    end

    def humanized_bot_name(profile_name)
      profile_name.to_s.tr("_-", " ").split.map(&:capitalize).join(" ")
    end

    def profiles_by_name(profile_rows)
      profile_names = profile_rows.map { |row| row.fetch(:profile_name) }
      AiProfile.where(profile_name: profile_names).index_by(&:profile_name)
    end

    def tick(entity, action)
      summary.fetch(entity)[action] += 1
    end
  end
end
