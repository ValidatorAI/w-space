module Mcp
  class Server < ApplicationRecord
    self.table_name = "mcps"

    TRANSPORT_HTTP = "http"
    TRANSPORT_STDIO = "stdio"
    AUTHENTICATION_NONE = "none"
    AUTHENTICATION_BEARER = "bearer"
    STATUS_ACTIVE = "active"
    STATUS_INACTIVE = "inactive"

    TRANSPORTS = [ TRANSPORT_HTTP, TRANSPORT_STDIO ].freeze
    AUTHENTICATIONS = [ AUTHENTICATION_NONE, AUTHENTICATION_BEARER ].freeze
    STATUSES = [ STATUS_ACTIVE, STATUS_INACTIVE ].freeze

    has_many :ai_profile_mcps, class_name: "AiProfileMcp", foreign_key: :mcp_id, dependent: :destroy
    has_many :ai_profiles, through: :ai_profile_mcps

    before_validation :normalize_transport_attributes

    scope :active, -> { where(status: "active") }

    validates :name, :transport, :status, presence: true
    validates :url, :authentication, presence: true, if: :http_transport?
    validates :bearer_token, presence: true, if: :bearer_authentication?
    validates :command, :args, presence: true, if: :stdio_transport?

    validates :transport, inclusion: { in: TRANSPORTS }
    validates :status, inclusion: { in: STATUSES }
    validates :authentication, inclusion: { in: AUTHENTICATIONS }, if: :http_transport?

    validates :name, :transport, :url, :authentication, :bearer_token, :status, :command, length: { maximum: 255 }, allow_blank: true

    private

    def http_transport?
      transport == TRANSPORT_HTTP
    end

    def stdio_transport?
      transport == TRANSPORT_STDIO
    end

    def bearer_authentication?
      http_transport? && authentication == AUTHENTICATION_BEARER
    end

    def normalize_transport_attributes
      if stdio_transport?
        self.url = ""
        self.authentication = AUTHENTICATION_NONE
        self.bearer_token = nil
      elsif http_transport?
        self.command = nil
        self.args = nil
        self.environment = nil
        self.bearer_token = nil unless authentication == AUTHENTICATION_BEARER
      end
    end
  end
end