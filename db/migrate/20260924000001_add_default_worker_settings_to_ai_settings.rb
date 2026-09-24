class AddDefaultWorkerSettingsToAiSettings < ActiveRecord::Migration[8.0]
  DEFAULT_AI_SETTINGS = {
    "max_number_of_workers" => 3,
    "max_spawn_depth" => 1
  }.freeze

  def up
    return unless table_exists?(:ai_settings)

    DEFAULT_AI_SETTINGS.each do |label, setting_value|
      next if AiSetting.exists?(label: label)

      AiSetting.create!(label: label, setting_value: setting_value)
    end
  end

  def down
    return unless table_exists?(:ai_settings)

    AiSetting.where(label: DEFAULT_AI_SETTINGS.keys).delete_all
  end
end
