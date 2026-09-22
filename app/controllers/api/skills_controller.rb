module Api
  class SkillsController < Api::BaseController
    SKILL_FIELDS = %i[id name category description add_by_default created_at updated_at].freeze

    def index
      skills = Skill.order(:name, :id)
      render json: {
        count: skills.count,
        skills: skills.map { |skill| serialize(skill) }
      }
    end

    def show
      skill = Skill.find_by(id: params[:id])
      return render json: { error: "Skill not found" }, status: :not_found unless skill

      render json: serialize(skill)
    end

    private

    def serialize(skill)
      skill.as_json(only: SKILL_FIELDS).merge(
        skill_text_present: skill.skill_text.present?,
        skill_text_length: skill.skill_text.to_s.length
      )
    end
  end
end
