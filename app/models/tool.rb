class Tool < ApplicationRecord
  has_many :ai_profile_tools, dependent: :destroy
  has_many :ai_profiles, through: :ai_profile_tools

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validates :name, presence: true, length: { maximum: 255 }
end
