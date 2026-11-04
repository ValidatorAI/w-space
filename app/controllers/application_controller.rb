class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, BlockBannedRequests, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName

  helper_method :ai_config_page_enabled?

  def ai_config_page_enabled?
    ENV.fetch("ENABLE_AI_CONFIG_PAGE", "FALSE").to_s.strip.casecmp("true").zero?
  end
end
