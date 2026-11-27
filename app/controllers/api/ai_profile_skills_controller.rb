module Api
  class AiProfileSkillsController < Api::BaseController
    include AiAdminEvents

    AI_PROFILE_SKILL_FIELDS = %i[id ai_profile_id skill_id enabled created_at updated_at].freeze

    before_action :set_profile, only: %i[toggle_enabled]
    before_action :ensure_toolset_editable!, only: %i[toggle_enabled]

    def index
      ai_profile_skills = AiProfileSkill.order(:ai_profile_id, :skill_id, :id)
      ai_profile_skills = ai_profile_skills.where(ai_profile_id: params[:ai_profile_id]) if params[:ai_profile_id].present?
      ai_profile_skills = ai_profile_skills.where(skill_id: params[:skill_id]) if params[:skill_id].present?

      render json: {
        count: ai_profile_skills.count,
        ai_profile_skills: ai_profile_skills.as_json(only: AI_PROFILE_SKILL_FIELDS)
      }
    end

    def show
      ai_profile_skill = AiProfileSkill.find_by(id: params[:id])
      return render json: { error: "AI profile skill assignment not found" }, status: :not_found unless ai_profile_skill

      render json: ai_profile_skill.as_json(only: AI_PROFILE_SKILL_FIELDS)
    end

    def toggle_enabled
      relation = @profile.ai_profile_skills.find_or_initialize_by(skill_id: params[:skill_id])
      relation.enabled = cast_boolean(params[:enabled])

      if relation.save
        record_ai_admin_event(
          event_type: "ai_profile_skill_updated",
          record: relation,
          data: { "ai_profile_id" => @profile.id, "skill_id" => relation.skill_id, "enabled" => relation.enabled },
          actor: resolve_api_actor
        )
        render json: relation.as_json(only: AI_PROFILE_SKILL_FIELDS)
      else
        render json: { error: relation.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    private

    def set_profile
      @profile = AiProfile.find_by(id: params[:profile_id])
      return render json: { error: "AI profile not found" }, status: :not_found unless @profile
    end

    def ensure_toolset_editable!
      return if @profile.editable? && @profile.tool_sets_editable?

      render json: { error: "profile tool sets not editable" }, status: :forbidden
    end
  end
end
