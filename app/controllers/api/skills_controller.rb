module Api
  class SkillsController < Api::BaseController
    include AiAdminEvents

    SKILL_FIELDS = %i[id name category description add_by_default created_at updated_at].freeze

    LEARN_SOURCE_KINDS = %w[local_file directory url notes].freeze

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

    def create
      skill = Skill.new(skill_params)
      if skill.save
        record_ai_admin_event(
          event_type: "skill_created",
          record: skill,
          data: skill_event_data(skill),
          actor: resolve_api_actor
        )
        render json: serialize(skill), status: :created
      else
        render json: { error: skill.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def update
      skill = Skill.find_by(id: params[:id])
      return render json: { error: "Skill not found" }, status: :not_found unless skill

      if skill.update(skill_params)
        record_ai_admin_event(
          event_type: "skill_updated",
          record: skill,
          data: skill_event_data(skill).merge("changed_fields" => changed_fields_for(skill)),
          actor: resolve_api_actor
        )
        render json: serialize(skill)
      else
        render json: { error: skill.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def destroy
      skill = Skill.find_by(id: params[:id])
      return render json: { error: "Skill not found" }, status: :not_found unless skill

      skill.destroy
      if skill.destroyed?
        record_ai_admin_event(
          event_type: "skill_deleted",
          record: skill,
          data: skill_event_data(skill),
          actor: resolve_api_actor
        )
      end

      head :no_content
    end

    def toggle_default
      skill = Skill.find_by(id: params[:id])
      return render json: { error: "Skill not found" }, status: :not_found unless skill

      if skill.update(add_by_default: cast_boolean(params[:add_by_default]))
        render json: serialize(skill)
      else
        render json: { error: skill.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def learn
      source_kind = params[:source_kind].to_s
      unless source_kind.in?(LEARN_SOURCE_KINDS)
        return render json: { error: "Invalid learn source" }, status: :unprocessable_entity
      end

      OutputEvents::Recorder.record(
        event_type: "skill_learning_requested",
        actor: resolve_api_actor,
        target_type: "Skill",
        data: {
          "content" => "Skill learning request from #{source_kind}",
          "content_payload" => {
            "type" => "skill_learning_request",
            "source_kind" => source_kind,
            "source_reference" => params[:source_reference],
            "notes" => params[:notes],
            "skill_name" => params[:skill_name],
            "skill_category" => params[:skill_category]
          }.compact
        }
      )

      render json: { status: "queued" }, status: :accepted
    end

    private

    def serialize(skill)
      skill.as_json(only: SKILL_FIELDS).merge(
        skill_text_present: skill.skill_text.present?,
        skill_text_length: skill.skill_text.to_s.length
      )
    end

    def skill_params
      params.require(:skill).permit(:name, :category, :description, :skill_text, :add_by_default)
    end
  end
end
