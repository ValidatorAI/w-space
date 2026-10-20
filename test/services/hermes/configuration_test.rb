require "test_helper"

class HermesConfigurationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  teardown do
    Hermes.reset_configuration!
  end

  test "has expected default configuration" do
    config = Hermes.configuration
    assert_equal "http://127.0.0.1:8642", config.base_uri
    assert_equal "http://127.0.0.1:9119", config.status_uri
    assert_equal "hermes", config.model
    assert_equal "delegator", config.default_profile
    assert_equal 60.0, config.timeout
    assert_equal 2, config.max_active_agents
    assert_equal 1.5, config.event_merge_settle_seconds
    assert_equal 900, config.event_recovery_max_age_seconds
    assert_equal 5, config.max_attachments
    assert_equal 20_971_520, config.max_attachment_bytes
  end

  test "configure block updates configuration attributes" do
    Hermes.configure do |c|
      c.base_uri = "https://custom-hermes.example.com"
      c.model = "deepseek-v4-flash"
      c.default_profile = "coder"
      c.timeout = 30.0
      c.event_merge_settle_seconds = 2.5
      c.max_attachments = 8
    end

    assert_equal "https://custom-hermes.example.com", Hermes.configuration.base_uri
    assert_equal "deepseek-v4-flash", Hermes.configuration.model
    assert_equal "coder", Hermes.configuration.default_profile
    assert_equal 30.0, Hermes.configuration.timeout
    assert_equal 2.5, Hermes.configuration.event_merge_settle_seconds
    assert_equal 8, Hermes.configuration.max_attachments

    # Verify consumers pick up the configuration
    client = Hermes::Client.new
    assert_equal "https://custom-hermes.example.com", client.base_uri
    assert_equal "coder", client.default_profile
    assert_equal "deepseek-v4-flash", client.model
    assert_equal 30.0, client.timeout

    assert_equal 2.5.seconds, OutputEvents::Deduplicator.settle_delay
    assert_equal 8, Hermes::AttachmentResolver.max_attachments
  end
end
