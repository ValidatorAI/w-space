module Hermes
  class Configuration
    DEFAULT_BASE_URI = "http://127.0.0.1:8642".freeze
    DEFAULT_STATUS_URI = "http://127.0.0.1:9119".freeze
    DEFAULT_MODEL = "hermes".freeze
    DEFAULT_PROFILE = "delegator".freeze
    DEFAULT_TIMEOUT = 60.0
    DEFAULT_MAX_ACTIVE_AGENTS = 2
    DEFAULT_SETTLE_SECONDS = 1.5
    DEFAULT_RECOVERY_MAX_AGE = 900
    DEFAULT_MAX_ATTACHMENTS = 5
    DEFAULT_MAX_ATTACHMENT_BYTES = 20_971_520 # 20MB

    attr_accessor :base_uri,
                  :status_uri,
                  :api_key,
                  :model,
                  :default_profile,
                  :timeout,
                  :max_active_agents,
                  :event_merge_settle_seconds,
                  :event_recovery_max_age_seconds,
                  :max_attachments,
                  :max_attachment_bytes,
                  :restart_trigger_path

    def initialize
      reset!
    end

    def reset!
      @base_uri = (ENV["HERMES_BASE_URI"] || ENV["BASE_URI"] || DEFAULT_BASE_URI).chomp("/")
      @status_uri = (ENV["HERMES_STATUS_URI"] || ENV["STATUS_BASE_URI"] || DEFAULT_STATUS_URI).chomp("/")
      @api_key = ENV["HERMES_API_KEY"] || ENV["API_SERVER_KEY"] || ENV["API_KEY"]
      @model = ENV["HERMES_MODEL"] || ENV["MODEL"] || DEFAULT_MODEL
      @default_profile = ENV["HERMES_DEFAULT_PROFILE"] || ENV["BASE_HERMES_PROFILE"] || DEFAULT_PROFILE
      @timeout = (ENV["HERMES_HTTP_TIMEOUT"] || DEFAULT_TIMEOUT).to_f
      @max_active_agents = (ENV["HERMES_MAX_ACTIVE_AGENTS"] || DEFAULT_MAX_ACTIVE_AGENTS).to_i
      @event_merge_settle_seconds = (ENV["EVENT_MERGE_SETTLE_SECONDS"] || ENV["SPACE_EVENT_MERGE_SETTLE_SECONDS"] || DEFAULT_SETTLE_SECONDS).to_f
      @event_recovery_max_age_seconds = (ENV["EVENT_RECOVERY_MAX_AGE_SECONDS"] || ENV["SPACE_EVENT_RECOVERY_MAX_AGE_SECONDS"] || DEFAULT_RECOVERY_MAX_AGE).to_i
      @max_attachments = (ENV["HERMES_EVENT_MAX_ATTACHMENTS"] || DEFAULT_MAX_ATTACHMENTS).to_i
      @max_attachment_bytes = (ENV["HERMES_EVENT_MAX_ATTACHMENT_BYTES"] || DEFAULT_MAX_ATTACHMENT_BYTES).to_i
      @restart_trigger_path = ENV["RESTART_TRIGGER_PATH"] || (defined?(Rails.root) && Rails.root ? Rails.root.join("tmp/restart.txt").to_s : "/triggers/restart")
    end
  end
end
