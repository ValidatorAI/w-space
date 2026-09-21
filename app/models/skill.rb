class Skill < ApplicationRecord
  has_many :ai_profile_skills, dependent: :destroy
  has_many :ai_profiles, through: :ai_profile_skills

  scope :default_enabled, -> { where(add_by_default: true) }
  scope :default_disabled, -> { where(add_by_default: false) }

  validates :name, presence: true, length: { maximum: 255 }
  validates :category, length: { maximum: 255 }, allow_blank: true
end
