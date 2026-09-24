class Users::AiAdminController < ApplicationController
  LEARN_SOURCE_KINDS = %w[local_file directory url notes].freeze

  before_action :ensure_can_administer
  before_action :set_profile, only: %i[
    show_profile
    update_profile
    destroy_profile
    reset_ai_config
    toggle_profile_tool
    toggle_profile_skill
    toggle_profile_mcp
  ]
  before_action :set_mcp, only: %i[edit_mcp update_mcp destroy_mcp]
  before_action :set_skill, only: %i[edit_skill update_skill destroy_skill toggle_skill_default]
  before_action :ensure_profile_editable!, only: %i[update_profile destroy_profile]
  before_action :ensure_profile_toolset_editable!, only: %i[toggle_profile_tool toggle_profile_skill toggle_profile_mcp]

  def index
    load_profiles_data
  end

  def new_profile
    @new_profile = build_new_profile
    @return_to = sanitized_return_path(params[:return_to]) || ai_admin_index_path
  end

  def general_settings
    @ai_settings = AiSetting.order(:label, :id)
    @new_ai_setting = AiSetting.new
  end

  def mcps
    @mcps = Mcp::Server.order(:name, :id)
  end

  def new_mcp
    @mcp = build_new_mcp
  end

  def edit_mcp
  end

  def tools
    @tools = Tool.order(:name, :id)
  end

  def skills
    @skills = Skill.order(:name, :id)
  end

  def new_skill
    @skill = build_new_skill
  end

  def edit_skill
  end

  def learn_skill_page
  end

  def show_profile
    load_profile_page_data
    load_profile_assignment_state
  end

  def create_ai_setting
    ai_setting = AiSetting.new(ai_setting_params)

    if ai_setting.save
      record_ai_admin_event(
        event_type: "ai_setting_created",
        record: ai_setting,
        data: ai_setting_event_data(ai_setting)
      )
      redirect_to ai_admin_general_settings_path, notice: "AI setting added"
    else
      redirect_to ai_admin_general_settings_path, alert: ai_setting.errors.full_messages.to_sentence.presence || "Unable to add AI setting"
    end
  end

  def update_ai_setting
    ai_setting = AiSetting.find(params[:id])

    if ai_setting.update(ai_setting_params)
      record_ai_admin_event(
        event_type: "ai_setting_updated",
        record: ai_setting,
        data: ai_setting_event_data(ai_setting).merge("changed_fields" => changed_fields_for(ai_setting))
      )
      redirect_to ai_admin_general_settings_path, notice: "AI setting updated"
    else
      redirect_to ai_admin_general_settings_path, alert: ai_setting.errors.full_messages.to_sentence.presence || "Unable to update AI setting"
    end
  end

  def destroy_ai_setting
    ai_setting = AiSetting.find(params[:id])
    ai_setting.destroy
    if ai_setting.destroyed?
      record_ai_admin_event(
        event_type: "ai_setting_deleted",
        record: ai_setting,
        data: ai_setting_event_data(ai_setting)
      )
    end

    redirect_to ai_admin_general_settings_path, notice: "AI setting deleted"
  end

  def create_mcp
    mcp = Mcp::Server.new(mcp_params)

    if mcp.save
      record_ai_admin_event(
        event_type: "mcp_created",
        record: mcp,
        data: mcp_event_data(mcp)
      )
      redirect_to ai_admin_mcps_page_path, notice: "MCP added"
    else
      @mcp = mcp
      flash.now[:alert] = mcp.errors.full_messages.to_sentence.presence || "Unable to add MCP"
      render :new_mcp, status: :unprocessable_entity
    end
  end

  def update_mcp
    if @mcp.update(mcp_params)
      record_ai_admin_event(
        event_type: "mcp_updated",
        record: @mcp,
        data: mcp_event_data(@mcp).merge("changed_fields" => changed_fields_for(@mcp))
      )
      redirect_to ai_admin_mcps_page_path, notice: "MCP updated"
    else
      flash.now[:alert] = @mcp.errors.full_messages.to_sentence.presence || "Unable to update MCP"
      render :edit_mcp, status: :unprocessable_entity
    end
  end

  def destroy_mcp
    @mcp.destroy
    if @mcp.destroyed?
      record_ai_admin_event(
        event_type: "mcp_deleted",
        record: @mcp,
        data: mcp_event_data(@mcp)
      )
    end

    redirect_to ai_admin_mcps_page_path, notice: "MCP deleted"
  end

  def toggle_tool
    tool = Tool.find(params[:id])

    if tool.update(active: cast_boolean(params[:active]))
      redirect_to ai_admin_tools_page_path, notice: "Tool updated"
    else
      redirect_to ai_admin_tools_page_path, alert: tool.errors.full_messages.to_sentence.presence || "Unable to update tool"
    end
  end

  def create_skill
    skill = Skill.new(skill_params)

    if skill.save
      record_ai_admin_event(
        event_type: "skill_created",
        record: skill,
        data: skill_event_data(skill)
      )
      redirect_to ai_admin_skills_page_path, notice: "Skill added"
    else
      @skill = skill
      flash.now[:alert] = skill.errors.full_messages.to_sentence.presence || "Unable to add skill"
      render :new_skill, status: :unprocessable_entity
    end
  end

  def update_skill
    if @skill.update(skill_params)
      record_ai_admin_event(
        event_type: "skill_updated",
        record: @skill,
        data: skill_event_data(@skill).merge("changed_fields" => changed_fields_for(@skill))
      )
      redirect_to ai_admin_skills_page_path, notice: "Skill updated"
    else
      flash.now[:alert] = @skill.errors.full_messages.to_sentence.presence || "Unable to update skill"
      render :edit_skill, status: :unprocessable_entity
    end
  end

  def destroy_skill
    @skill.destroy
    if @skill.destroyed?
      record_ai_admin_event(
        event_type: "skill_deleted",
        record: @skill,
        data: skill_event_data(@skill)
      )
    end

    redirect_to ai_admin_skills_page_path, notice: "Skill deleted"
  end

  def toggle_skill_default
    if @skill.update(add_by_default: cast_boolean(params[:add_by_default]))
      redirect_to ai_admin_skills_page_path, notice: "Skill default behavior updated"
    else
      redirect_to ai_admin_skills_page_path, alert: @skill.errors.full_messages.to_sentence.presence || "Unable to update skill default behavior"
    end
  end

  def learn_skill
    payload = learn_skill_params
    source_kind = payload[:source_kind].to_s

    unless source_kind.in?(LEARN_SOURCE_KINDS)
      flash.now[:alert] = "Invalid learn source"
      render :learn_skill_page, status: :unprocessable_entity
      return
    end

    content = "Skill learning request from #{source_kind}"
    if payload[:source_reference].present?
      content = "#{content}: #{payload[:source_reference]}"
    end

    OutputEvents::Recorder.record(
      event_type: "skill_learning_requested",
      actor: Current.user,
      target_type: "Skill",
      data: {
        "content" => content,
        "content_payload" => {
          "type" => "skill_learning_request",
          "source_kind" => source_kind,
          "source_reference" => payload[:source_reference],
          "notes" => payload[:notes],
          "skill_name" => payload[:skill_name],
          "skill_category" => payload[:skill_category]
        }.compact
      }
    )

    redirect_to ai_admin_skill_learn_page_path, notice: "Skill learning request queued"
  end

  def create_profile
    @return_to = sanitized_return_path(params[:return_to]) || ai_admin_index_path
    profile = AiProfile.new(profile_params)

    ActiveRecord::Base.transaction do
      normalize_profile_bot_name(profile)
      profile.save!
      AiProfiles::BotSync.call(profile: profile, previous_bot: false, previous_bot_name: nil)
    end

    record_ai_admin_event(
      event_type: "ai_profile_created",
      record: profile,
      data: ai_profile_event_data(profile)
    )

    redirect_to @return_to, notice: "Profile created"
  rescue ActiveRecord::RecordInvalid => error
    @new_profile = profile
    render_new_profile_with_error(error.record.errors.full_messages.to_sentence.presence || "Unable to create profile")
  end

  def update_profile
    previous_bot = @profile.bot
    previous_bot_name = @profile.bot_name

    @profile.assign_attributes(profile_params)

    ActiveRecord::Base.transaction do
      normalize_profile_bot_name(@profile)
      @profile.save!
      AiProfiles::BotSync.call(profile: @profile, previous_bot: previous_bot, previous_bot_name: previous_bot_name)
    end

    record_ai_admin_event(
      event_type: "ai_profile_updated",
      record: @profile,
      data: ai_profile_event_data(@profile).merge("changed_fields" => changed_fields_for(@profile))
    )

    redirect_to ai_admin_profile_path(@profile, anchor: "profile-edit"), notice: "Profile updated"
  rescue ActiveRecord::RecordInvalid => error
    render_profile_with_error(error.record.errors.full_messages.to_sentence.presence || "Unable to update profile")
  end

  def destroy_profile
    previous_bot_name = @profile.bot_name

    ActiveRecord::Base.transaction do
      if @profile.bot?
        @profile.bot = false
        AiProfiles::BotSync.call(profile: @profile, previous_bot: true, previous_bot_name: previous_bot_name)
      end
      @profile.destroy!
    end

    if @profile.destroyed?
      record_ai_admin_event(
        event_type: "ai_profile_deleted",
        record: @profile,
        data: ai_profile_event_data(@profile)
      )
    end

    redirect_to ai_admin_index_path, notice: "Profile deleted"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to ai_admin_profile_path(@profile, anchor: "profile-edit"), alert: error.record.errors.full_messages.to_sentence.presence || "Unable to delete profile"
  end

  def reset_ai_config_all
    perform_ai_config_reset!
    redirect_to ai_admin_index_path, notice: "AI config reset completed"
  rescue AiConfig::XmlLoader::ConfigError, ActiveRecord::RecordInvalid, KeyError => error
    redirect_to ai_admin_index_path, alert: "Unable to reset AI config: #{error.message}"
  end

  def reset_ai_config
    perform_ai_config_reset!

    notice = "AI config reset completed"

    if AiProfile.exists?(@profile.id)
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-edit"), notice: notice
    else
      redirect_to ai_admin_index_path, notice: "#{notice}. This profile was removed by reset."
    end
  rescue AiConfig::XmlLoader::ConfigError, ActiveRecord::RecordInvalid, KeyError => error
    redirect_to ai_admin_profile_path(@profile, anchor: "profile-edit"), alert: "Unable to reset AI config: #{error.message}"
  end

  def toggle_profile_tool
    relation = @profile.ai_profile_tools.find_or_initialize_by(tool_id: params[:tool_id])
    relation.enabled = cast_boolean(params[:enabled])

    if relation.save
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-tools"), notice: "Profile tool updated"
    else
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-tools"), alert: relation.errors.full_messages.to_sentence.presence || "Unable to update profile tool"
    end
  end

  def toggle_profile_skill
    relation = @profile.ai_profile_skills.find_or_initialize_by(skill_id: params[:skill_id])
    relation.enabled = cast_boolean(params[:enabled])

    if relation.save
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-skills"), notice: "Profile skill updated"
    else
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-skills"), alert: relation.errors.full_messages.to_sentence.presence || "Unable to update profile skill"
    end
  end

  def toggle_profile_mcp
    relation = @profile.ai_profile_mcps.find_or_initialize_by(mcp_id: params[:mcp_id])
    relation.active = cast_boolean(params[:active])

    if relation.save
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-mcps"), notice: "Profile MCP updated"
    else
      redirect_to ai_admin_profile_path(@profile, anchor: "profile-mcps"), alert: relation.errors.full_messages.to_sentence.presence || "Unable to update profile MCP"
    end
  end

  private

  def ensure_can_administer
    head :forbidden unless Current.user.can_administer?
  end

  def set_profile
    @profile = AiProfile.find(params[:id] || params[:profile_id])
  end

  def set_mcp
    @mcp = Mcp::Server.find(params[:id])
  end

  def set_skill
    @skill = Skill.find(params[:id])
  end

  def ensure_profile_editable!
    return if @profile.editable?

    redirect_to ai_admin_profile_path(@profile, anchor: "profile-edit"), alert: "This profile is read-only"
  end

  def ensure_profile_toolset_editable!
    return if @profile.editable? && @profile.tool_sets_editable?

    redirect_to ai_admin_profile_path(@profile, anchor: "profile-tools"), alert: "This profile does not allow tool, skill, or MCP assignment changes"
  end

  def load_profiles_data
    @profiles = AiProfile.order(:profile_name, :id)
    @related_bot_by_profile_id = build_related_bot_map(@profiles)
  end

  def build_related_bot_map(profiles)
    bots_by_name = {}
    User.where(role: :bot).includes(avatar_attachment: :blob).order(updated_at: :desc).each do |bot|
      [ bot.name, bot.display_name ].compact.each do |candidate_name|
        normalized_name = normalize_bot_name(candidate_name)
        next if normalized_name.blank?

        bots_by_name[normalized_name] ||= bot
      end
    end

    profiles.each_with_object({}) do |profile, map|
      map[profile.id] = find_related_bot_for_profile(profile, bots_by_name)
    end
  end

  def find_related_bot_for_profile(profile, bots_by_name)
    return nil unless profile.bot?

    [ profile.bot_name.to_s.strip.presence, inferred_bot_name(profile) ].compact.each do |candidate_name|
      bot = bots_by_name[normalize_bot_name(candidate_name)]
      return bot if bot.present?
    end

    nil
  end

  def normalize_bot_name(value)
    value.to_s.strip.downcase
  end

  def build_new_mcp
    Mcp::Server.new(
      status: Mcp::Server::STATUS_ACTIVE,
      authentication: Mcp::Server::AUTHENTICATION_NONE,
      transport: Mcp::Server::TRANSPORT_HTTP
    )
  end

  def build_new_skill
    Skill.new(add_by_default: false)
  end

  def build_new_profile
    AiProfile.new(
      bot: false,
      editable: true,
      tool_sets_editable: true,
      max_line_sessions: AiProfile::SESSION_LIMIT_DEFAULT,
      max_concurrent_sessions: AiProfile::SESSION_LIMIT_DEFAULT,
      auto_decompose_per_tick: AiProfile::SESSION_LIMIT_DEFAULT,
      max_in_progress_per_profile: AiProfile::SESSION_LIMIT_DEFAULT,
      max_number_of_workers: AiProfile::WORKER_LIMIT_DEFAULT,
      max_spawn_depth: AiProfile::SPAWN_DEPTH_DEFAULT
    )
  end

  def load_profile_page_data
    @tools = Tool.order(:name, :id)
    @skills = Skill.order(:name, :id)
    @mcps = Mcp::Server.order(:name, :id)
  end

  def load_profile_assignment_state
    @tool_enabled_map = @profile.ai_profile_tools.pluck(:tool_id, :enabled).to_h
    @skill_enabled_map = @profile.ai_profile_skills.pluck(:skill_id, :enabled).to_h
    @mcp_active_map = @profile.ai_profile_mcps.pluck(:mcp_id, :active).to_h
  end

  def normalize_profile_bot_name(profile)
    return unless profile.bot?

    profile.bot_name = profile.bot_name.to_s.strip.presence || inferred_bot_name(profile)
  end

  def inferred_bot_name(profile)
    profile.profile_name.to_s.tr("_-", " ").split.map(&:capitalize).join(" ")
  end

  def render_profile_with_error(message)
    load_profile_page_data
    load_profile_assignment_state
    flash.now[:alert] = message
    render :show_profile, status: :unprocessable_entity
  end

  def render_new_profile_with_error(message)
    @return_to ||= ai_admin_index_path
    flash.now[:alert] = message
    render :new_profile, status: :unprocessable_entity
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def ai_admin_index_path(anchor: nil)
    user_company_ai_admin_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_general_settings_path(anchor: nil)
    user_company_ai_admin_general_settings_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_mcps_page_path(anchor: nil)
    user_company_ai_admin_mcps_page_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_tools_page_path(anchor: nil)
    user_company_ai_admin_tools_page_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_skills_page_path(anchor: nil)
    user_company_ai_admin_skills_page_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_skill_learn_page_path(anchor: nil)
    user_company_ai_admin_skill_learn_page_path(user_id: "me", anchor: anchor)
  end

  def ai_admin_profile_path(profile, anchor: nil)
    user_company_ai_admin_profile_path(user_id: "me", id: profile.id, anchor: anchor)
  end

  def sanitized_return_path(value)
    return nil if value.blank?

    uri = URI.parse(value.to_s)
    return nil if uri.scheme.present? || uri.host.present?

    candidate_path = uri.to_s
    return nil unless candidate_path.start_with?("/")
    return nil unless candidate_path.start_with?(ai_admin_index_path)

    candidate_path
  rescue URI::InvalidURIError
    nil
  end

  def ai_setting_params
    params.require(:ai_setting).permit(:label, :setting_value)
  end

  def mcp_params
    params.require(:mcp).permit(:name, :transport, :url, :authentication, :bearer_token, :status, :command, :args, :environment)
  end

  def skill_params
    params.require(:skill).permit(:name, :category, :description, :skill_text, :add_by_default)
  end

  def learn_skill_params
    params.require(:learn).permit(:source_kind, :source_reference, :notes, :skill_name, :skill_category)
  end

  def profile_params
    params.require(:ai_profile).permit(
      :profile_name,
      :soul,
      :bot,
      :bot_name,
      :editable,
      :tool_sets_editable,
      :max_line_sessions,
      :max_concurrent_sessions,
      :auto_decompose_per_tick,
      :max_in_progress_per_profile,
      :max_number_of_workers,
      :max_spawn_depth
    )
  end

  def record_ai_admin_event(event_type:, record:, data: {})
    OutputEvents::Recorder.record(
      event_type: event_type,
      event_id: record.id,
      actor: Current.user,
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
      "max_line_sessions" => profile.max_line_sessions,
      "max_concurrent_sessions" => profile.max_concurrent_sessions,
      "auto_decompose_per_tick" => profile.auto_decompose_per_tick,
      "max_in_progress_per_profile" => profile.max_in_progress_per_profile,
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

  def perform_ai_config_reset!
    summary = AiConfig::ResetFromXml.call

    OutputEvents::Recorder.record(
      event_type: "ai_config_reset",
      actor: Current.user,
      target_type: "AiConfig",
      data: {
        "source_path" => AiConfig::XmlLoader::SOURCE_PATH.relative_path_from(Rails.root).to_s,
        "summary" => summary
      }
    )

    summary
  end
end
