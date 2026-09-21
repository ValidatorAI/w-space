class AiProfile < ApplicationRecord
  has_one_attached :profile_icon

  validates :profile_name, presence: true, length: { maximum: 255 }
  validates :bot_name, length: { maximum: 255 }, allow_blank: true
  validates :main_model, :fallback_model, :cloned_from, length: { maximum: 255 }, allow_blank: true
end