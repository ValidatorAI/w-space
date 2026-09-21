class Skill < ApplicationRecord
  scope :default_enabled, -> { where(add_by_default: true) }
  scope :default_disabled, -> { where(add_by_default: false) }

  validates :name, presence: true, length: { maximum: 255 }
  validates :category, length: { maximum: 255 }, allow_blank: true
end
