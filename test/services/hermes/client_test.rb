require "test_helper"

class HermesClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @client = Hermes::Client.new(
      base_uri: "http://127.0.0.1:8642",
      status_base_uri: "http://127.0.0.1:9119",
      api_key: "test-secret-key",
      default_profile: "delegator"
    )
  end

  test "build_url prefixes path with profile unless already prefixed or status" do
    assert_equal "http://127.0.0.1:8642/p/delegator/v1/chat/completions", @client.build_url("/v1/chat/completions")
    assert_equal "http://127.0.0.1:8642/p/coder/v1/chat/completions", @client.build_url("/v1/chat/completions", profile: "coder")
    assert_equal "http://127.0.0.1:8642/p/custom/v1/run", @client.build_url("/p/custom/v1/run")
    assert_equal "http://127.0.0.1:8642/api/status", @client.build_url("/api/status")
  end

  test "chat_completions posts json payload with session headers" do
    expected_response = {
      "choices" => [
        { "message" => { "role" => "assistant", "content" => "Task created" } }
      ]
    }

    stub = stub_request(:post, "http://127.0.0.1:8642/p/delegator/v1/chat/completions")
      .with(
        headers: {
          "Authorization" => "Bearer test-secret-key",
          "Content-Type" => "application/json",
          "X-Hermes-Session-Id" => "sess_123",
          "X-Hermes-Session-Key" => "key_abc"
        }
      )
      .to_return(status: 200, body: expected_response.to_json, headers: { "Content-Type" => "application/json" })

    payload = { messages: [{ role: "user", content: "Hi" }] }
    response = @client.chat_completions(
      payload,
      session_id: "sess_123",
      session_key: "key_abc"
    )

    assert_requested(stub)
    assert_equal "Task created", Hermes::PromptBuilder.extract_reply_text(response)
  end

  test "chat_completions sends multipart request when files are provided" do
    expected_response = {
      "choices" => [{ "message" => { "role" => "assistant", "content" => "Received file" } }]
    }

    stub = stub_request(:post, "http://127.0.0.1:8642/p/coder/v1/chat/completions")
      .with { |req|
        req.headers["Content-Type"].to_s.start_with?("multipart/form-data; boundary=") &&
          req.body.include?("Content-Disposition: form-data; name=\"payload\"") &&
          req.body.include?("Content-Disposition: form-data; name=\"file_1\"; filename=\"test.txt\"") &&
          req.body.include?("hello world content")
      }
      .to_return(status: 200, body: expected_response.to_json, headers: { "Content-Type" => "application/json" })

    files = {
      "file_1" => ["test.txt", "hello world content", "text/plain"]
    }

    response = @client.chat_completions(
      { messages: [{ role: "user", content: "Check file" }] },
      profile: "coder",
      files: files
    )

    assert_requested(stub)
    assert_equal "Received file", Hermes::PromptBuilder.extract_reply_text(response)
  end

  test "api_status_summary retrieves gateway load status" do
    status_payload = {
      "gateway_busy" => false,
      "active_agents" => 2,
      "active_sessions" => 5,
      "overall" => "healthy"
    }

    stub_request(:get, "http://127.0.0.1:9119/api/status")
      .with(headers: { "Authorization" => "Bearer test-secret-key" })
      .to_return(status: 200, body: status_payload.to_json, headers: { "Content-Type" => "application/json" })

    summary = @client.api_status_summary
    assert_equal false, summary["gateway_busy"]
    assert_equal 2, summary["active_agents"]
    assert_equal 5, summary["active_sessions"]
    assert_equal "healthy", summary["overall"]
  end
end
