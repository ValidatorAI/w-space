# Initialize Hermes configuration from environment variables and application defaults
Rails.application.config.to_prepare do
  Hermes.configure do |config|
    config.reset!
  end

  Rails.logger.info(
    "[Hermes] Configured: base_uri=#{Hermes.configuration.base_uri}, " \
    "status_uri=#{Hermes.configuration.status_uri}, " \
    "model=#{Hermes.configuration.model}, " \
    "default_profile=#{Hermes.configuration.default_profile}"
  )
end
