class AddWorkerAndSpawnLimitsToAiProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_profiles, :max_number_of_workers, :integer, default: 3, null: false
    add_column :ai_profiles, :max_spawn_depth, :integer, default: 1, null: false
  end
end
