module Api
  class AiProfileSkillsController < Api::BaseController
    AI_PROFILE_SKILL_FIELDS = %i[id ai_profile_id skill_id enabled created_at updated_at].freeze

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
  end
end
