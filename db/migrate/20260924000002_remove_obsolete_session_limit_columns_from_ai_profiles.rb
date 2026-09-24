class RemoveObsoleteSessionLimitColumnsFromAiProfiles < ActiveRecord::Migration[8.0]
  def up
    %i[
      max_line_sessions
      max_concurrent_sessions
      auto_decompose_per_tick
      max_in_progress_per_profile
    ].each do |column_name|
      remove_column :ai_profiles, column_name if column_exists?(:ai_profiles, column_name)
    end
  end

  def down
    add_column :ai_profiles, :max_line_sessions, :integer, default: 2, null: false unless column_exists?(:ai_profiles, :max_line_sessions)
    add_column :ai_profiles, :max_concurrent_sessions, :integer, default: 2, null: false unless column_exists?(:ai_profiles, :max_concurrent_sessions)
    add_column :ai_profiles, :auto_decompose_per_tick, :integer, default: 2, null: false unless column_exists?(:ai_profiles, :auto_decompose_per_tick)
    add_column :ai_profiles, :max_in_progress_per_profile, :integer, default: 2, null: false unless column_exists?(:ai_profiles, :max_in_progress_per_profile)
  end
end
