class AddSessionLimitsToAiProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_profiles, :max_line_sessions, :integer, default: 2, null: false
    add_column :ai_profiles, :max_concurrent_sessions, :integer, default: 2, null: false
    add_column :ai_profiles, :auto_decompose_per_tick, :integer, default: 2, null: false
    add_column :ai_profiles, :max_in_progress_per_profile, :integer, default: 2, null: false
  end
end