module Api
  class AiProfilesController < Api::BaseController
    AI_PROFILE_FIELDS = %i[
      id profile_name bot bot_name editable tool_sets_editable
      max_line_sessions max_concurrent_sessions auto_decompose_per_tick
      max_in_progress_per_profile main_model fallback_model cloned_from
      created_at updated_at
    ].freeze

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

    private

    def serialize(profile)
      profile.as_json(only: AI_PROFILE_FIELDS).merge(
        soul_present: profile.soul.present?,
        soul_length: profile.soul.to_s.length
      )
    end
  end
end
