module Api
  class AiProfilesController < Api::BaseController
    include AiAdminEvents

    AI_PROFILE_FIELDS = %i[
      id profile_name bot bot_name editable tool_sets_editable
      main_model fallback_model cloned_from
      created_at updated_at
    ].freeze

    before_action :set_profile, only: %i[update destroy reset_ai_config]
    before_action :ensure_profile_editable!, only: %i[update destroy]

    def index
      profiles = AiProfile.order(:profile_name, :id)
      render json: {
        count: profiles.count,
        ai_profiles: profiles.map { |profile| serialize(profile) }
      }
    end

    def show
      profile = AiProfile.find_by(id: params[:id])
      return render json: { error: "AI profile not found" }, status: :not_found unless profile

      render json: serialize(profile)
    end

    def create
      profile = AiProfile.new(ai_profile_params)

      begin
        ActiveRecord::Base.transaction do
          normalize_profile_bot_name(profile)
          profile.save!
          AiProfiles::BotSync.call(profile: profile, previous_bot: false, previous_bot_name: nil)
        end
      rescue ActiveRecord::RecordInvalid => e
        return render json: { error: e.record.errors.full_messages.to_sentence.presence || "Unable to create profile" }, status: :unprocessable_entity
      end

      record_ai_admin_event(
        event_type: "ai_profile_created",
        record: profile,
        data: ai_profile_event_data(profile),
        actor: resolve_api_actor
      )

      render json: serialize(profile), status: :created
    end

    def update
      previous_bot = @profile.bot
      previous_bot_name = @profile.bot_name

      @profile.assign_attributes(ai_profile_params)

      begin
        ActiveRecord::Base.transaction do
          normalize_profile_bot_name(@profile)
          @profile.save!
          AiProfiles::BotSync.call(profile: @profile, previous_bot: previous_bot, previous_bot_name: previous_bot_name)
        end
      rescue ActiveRecord::RecordInvalid => e
        return render json: { error: e.record.errors.full_messages.to_sentence.presence || "Unable to update profile" }, status: :unprocessable_entity
      end

      record_ai_admin_event(
        event_type: "ai_profile_updated",
        record: @profile,
        data: ai_profile_event_data(@profile).merge("changed_fields" => changed_fields_for(@profile)),
        actor: resolve_api_actor
      )

      render json: serialize(@profile)
    end

    def destroy
      AiProfiles::Destroy.call(profile: @profile, actor: resolve_api_actor)
      record_ai_admin_event(
        event_type: "ai_profile_deleted",
        record: @profile,
        data: ai_profile_event_data(@profile),
        actor: resolve_api_actor
      ) if @profile.destroyed?

      head :no_content
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence.presence || "Unable to delete profile" }, status: :unprocessable_entity
    end

    def reset_ai_config
      begin
        summary = AiConfig::ResetFromXml.call
        OutputEvents::Recorder.record(
          event_type: "ai_config_reset",
          actor: resolve_api_actor,
          target_type: "AiConfig",
          data: {
            "source_path" => AiConfig::XmlLoader::SOURCE_PATH.relative_path_from(Rails.root).to_s,
            "summary" => summary
          }
        )
      rescue AiConfig::XmlLoader::ConfigError, ActiveRecord::RecordInvalid, KeyError => e
        return render json: { error: e.message }, status: :unprocessable_entity
      end

      render json: { status: "ok", summary: summary }
    end

    private

    def set_profile
      @profile = AiProfile.find_by(id: params[:id] || params[:profile_id])
      return render json: { error: "AI profile not found" }, status: :not_found unless @profile
    end

    def ensure_profile_editable!
      return if @profile.editable?

      render json: { error: "profile not editable" }, status: :forbidden
    end

    def serialize(profile)
      profile.as_json(only: AI_PROFILE_FIELDS).merge(
        soul_present: profile.soul.present?,
        soul_length: profile.soul.to_s.length
      )
    end

    def normalize_profile_bot_name(profile)
      return unless profile.bot?

      profile.bot_name = profile.bot_name.to_s.strip.presence || inferred_bot_name(profile)
    end

    def inferred_bot_name(profile)
      profile.profile_name.to_s.tr("_-", " ").split.map(&:capitalize).join(" ")
    end

    def ai_profile_params
      params.require(:ai_profile).permit(
        :profile_name,
        :soul,
        :bot,
        :bot_name,
        :editable,
        :tool_sets_editable,
        :max_number_of_workers,
        :max_spawn_depth
      )
    end
  end
end
