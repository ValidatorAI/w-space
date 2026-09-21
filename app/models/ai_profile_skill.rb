class AiProfileSkill < ApplicationRecord
  belongs_to :ai_profile
  belongs_to :skill

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
end
