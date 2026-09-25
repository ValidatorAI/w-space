class AiProfileTool < ApplicationRecord
  belongs_to :ai_profile
  belongs_to :tool

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
end
