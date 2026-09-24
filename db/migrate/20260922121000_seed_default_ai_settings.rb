class SeedDefaultAiSettings < ActiveRecord::Migration[8.0]
  DEFAULT_AI_SETTINGS = {
    "max_line_sessions" => 2,
    "max_concurrent_sessions" => 2,
    "auto_decompose_per_tick" => 2,
    "max_in_progress_per_profile" => 2,
    "max_number_of_workers" => 3,
    "max_spawn_depth" => 1
  }.freeze

  def up
    return unless table_exists?(:ai_settings)

    now = Time.current

    DEFAULT_AI_SETTINGS.each do |label, setting_value|
      setting = ai_settings_relation.find_or_initialize_by(label: label)
      setting.setting_value = setting_value
      setting.created_at ||= now
      setting.updated_at = now
      setting.save! if setting.new_record? || setting.changed?
    end
  end

  def down
    return unless table_exists?(:ai_settings)

    ai_settings_relation.where(label: DEFAULT_AI_SETTINGS.keys).delete_all
  end

  private

  def ai_settings_relation
    @ai_settings_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ai_settings"
    end
  end
end