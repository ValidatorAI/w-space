class AiProfile < ApplicationRecord
  SESSION_LIMIT_DEFAULT = 2
  SESSION_LIMIT_COLUMNS = %i[
    max_line_sessions
    max_concurrent_sessions
    auto_decompose_per_tick
    max_in_progress_per_profile
  ].freeze

  has_one_attached :profile_icon
  has_many :ai_profile_skills, dependent: :destroy
  has_many :skills, through: :ai_profile_skills
  has_many :ai_profile_tools, dependent: :destroy
  has_many :tools, through: :ai_profile_tools
  has_many :ai_profile_mcps, dependent: :destroy
  has_many :mcps, through: :ai_profile_mcps, source: :mcp

  validates :profile_name, presence: true, length: { maximum: 255 }
  validates :bot_name, length: { maximum: 255 }, allow_blank: true
  validates :main_model, :fallback_model, :cloned_from, length: { maximum: 255 }, allow_blank: true
end