module Mcp
  class Server < ApplicationRecord
    self.table_name = "mcps"

    has_many :ai_profile_mcps, class_name: "AiProfileMcp", foreign_key: :mcp_id, dependent: :destroy
    has_many :ai_profiles, through: :ai_profile_mcps

    scope :active, -> { where(status: "active") }

    validates :name, :transport, :url, :authentication, :status, presence: true
    validates :name, :transport, :url, :authentication, :bearer_token, :status, length: { maximum: 255 }, allow_blank: true
  end
end