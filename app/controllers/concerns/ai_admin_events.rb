module AiAdminEvents
  extend ActiveSupport::Concern

  private

  def record_ai_admin_event(event_type:, record:, data: {}, actor: nil)
    actor ||= if defined?(Current) && Current.respond_to?(:user)
      Current.user
    elsif respond_to?(:resolve_api_actor, true)
      resolve_api_actor
    end

    OutputEvents::Recorder.record(
      event_type: event_type,
      event_id: record.id,
      actor: actor,
      target_type: record.class.name,
      data: data
    )
  end

  def changed_fields_for(record)
    record.previous_changes.except("created_at", "updated_at").keys
  end

  def ai_setting_event_data(ai_setting)
    {
      "label" => ai_setting.label,
      "setting_value" => ai_setting.setting_value
    }
  end

  def mcp_event_data(mcp)
    {
      "name" => mcp.name,
      "transport" => mcp.transport,
      "authentication" => mcp.authentication,
      "status" => mcp.status,
      "url_present" => mcp.url.present?
    }
      .merge(text_field_metadata(mcp.bearer_token, "bearer_token"))
      .merge(text_field_metadata(mcp.command, "command"))
      .merge(text_field_metadata(mcp.args, "args"))
      .merge(text_field_metadata(mcp.environment, "environment"))
  end

  def skill_event_data(skill)
    {
      "name" => skill.name,
      "category" => skill.category,
      "add_by_default" => skill.add_by_default
    }
      .merge(text_field_metadata(skill.description, "description"))
      .merge(text_field_metadata(skill.skill_text, "skill_text"))
  end

  def ai_profile_event_data(profile)
    {
      "profile_name" => profile.profile_name,
      "bot" => profile.bot,
      "bot_name" => profile.bot_name,
      "editable" => profile.editable,
      "tool_sets_editable" => profile.tool_sets_editable,
      "max_number_of_workers" => profile.max_number_of_workers,
      "max_spawn_depth" => profile.max_spawn_depth
    }.merge(text_field_metadata(profile.soul, "soul"))
  end

  def text_field_metadata(value, key)
    text = value.to_s
    present = value.present?

    {
      "#{key}_present" => present,
      "#{key}_length" => present ? text.length : 0
    }
  end
end
