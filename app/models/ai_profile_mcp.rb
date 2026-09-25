class AiProfileMcp < ApplicationRecord
  belongs_to :ai_profile
  belongs_to :mcp, class_name: "Mcp::Server"

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
end