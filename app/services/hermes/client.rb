require "net/http"
require "uri"
require "json"
require "securerandom"

module Hermes
  class Client
    class HttpError < StandardError
      attr_reader :status_code, :response_body

      def initialize(message, status_code: nil, response_body: nil)
        super(message)
        @status_code = status_code
        @response_body = response_body
      end
    end

    attr_reader :base_uri, :status_base_uri, :api_key, :default_profile, :model, :timeout

    def initialize(
      base_uri: nil,
      status_base_uri: nil,
      api_key: nil,
      default_profile: nil,
      model: nil,
      timeout: nil
    )
      config = Hermes.configuration
      @base_uri = (base_uri || config.base_uri).chomp("/")
      @status_base_uri = (status_base_uri || config.status_uri).chomp("/")
      @api_key = api_key || config.api_key
      @default_profile = default_profile || config.default_profile
      @model = model || config.model
      @timeout = (timeout || config.timeout).to_f
    end

    def chat_completions(
      payload,
      profile: nil,
      files: nil,
      session_id: nil,
      session_key: nil,
      timeout: nil
    )
      request_payload = payload.dup
      request_payload[:model] ||= @model if request_payload.is_a?(Hash)

      target_profile = profile.presence || @default_profile

      if files.present?
        post_multipart(
          "/v1/chat/completions",
          payload: request_payload,
          files: files,
          profile: target_profile,
          session_id: session_id,
          session_key: session_key,
          timeout: timeout
        )
      else
        post_json(
          "/v1/chat/completions",
          payload: request_payload,
          profile: target_profile,
          session_id: session_id,
          session_key: session_key,
          timeout: timeout
        )
      end
    end

    def api_status
      url = URI("#{@status_base_uri}/api/status")
      req = Net::HTTP::Get.new(url, auth_headers(include_json: true))
      response = execute_http(url, req, timeout: @timeout)
      parse_json(response)
    rescue StandardError => e
      { "overall" => "unavailable", "error" => e.message }
    end

    def api_status_summary
      status = api_status
      {
        "gateway_busy" => status["gateway_busy"],
        "active_agents" => status["active_agents"],
        "active_sessions" => status["active_sessions"],
        "overall" => status["overall"]
      }
    end

    def build_url(path, profile: nil)
      normalized_path = path.start_with?("/") ? path : "/#{path}"

      if normalized_path.start_with?("/p/") || normalized_path == "/api/status"
        "#{@base_uri}#{normalized_path}"
      else
        prof = (profile.presence || @default_profile).to_s.strip.delete_prefix("/").delete_suffix("/")
        prof = "default" if prof.empty?
        "#{@base_uri}/p/#{prof}#{normalized_path}"
      end
    end

    private

    def post_json(path, payload:, profile:, session_id: nil, session_key: nil, timeout: nil)
      url = URI(build_url(path, profile: profile))
      req = Net::HTTP::Post.new(url, auth_headers(session_id: session_id, session_key: session_key, include_json: true))
      req.body = payload.to_json

      response = execute_http(url, req, timeout: timeout || @timeout)
      parse_json(response)
    end

    def post_multipart(path, payload:, files:, profile:, session_id: nil, session_key: nil, timeout: nil)
      url = URI(build_url(path, profile: profile))
      boundary = "----HermesMultipartBoundary#{SecureRandom.hex(16)}"

      headers = auth_headers(session_id: session_id, session_key: session_key, include_json: false)
      headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

      req = Net::HTTP::Post.new(url, headers)
      req.body = build_multipart_body(boundary: boundary, payload: payload, files: files)

      response = execute_http(url, req, timeout: timeout || @timeout)
      parse_json(response)
    end

    def build_multipart_body(boundary:, payload:, files:)
      body = "".b

      # Payload JSON form field
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"payload\"\r\n"
      body << "Content-Type: application/json; charset=utf-8\r\n\r\n"
      body << payload.to_json
      body << "\r\n"

      # File attachments: files format { "file_1" => [filename, bytes, content_type] }
      files.each do |field_name, file_info|
        filename, data_bytes, content_type = file_info
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"#{field_name}\"; filename=\"#{filename}\"\r\n"
        body << "Content-Type: #{content_type || 'application/octet-stream'}\r\n\r\n"
        body << data_bytes.to_s.b
        body << "\r\n"
      end

      body << "--#{boundary}--\r\n"
      body
    end

    def auth_headers(session_id: nil, session_key: nil, include_json: true)
      headers = {}
      headers["Authorization"] = "Bearer #{@api_key}" if @api_key.present?
      headers["Content-Type"] = "application/json" if include_json
      headers["X-Hermes-Session-Id"] = session_id if session_id.present?
      headers["X-Hermes-Session-Key"] = session_key if session_key.present?
      headers
    end

    def execute_http(url, req, timeout:)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout

      response = http.request(req)
      unless response.is_a?(Net::HTTPSuccess)
        raise HttpError.new(
          "Hermes API request returned HTTP #{response.code}: #{response.body}",
          status_code: response.code.to_i,
          response_body: response.body
        )
      end
      response
    end

    def parse_json(response)
      return {} if response.body.blank?
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise HttpError.new("Failed to parse JSON response from Hermes: #{e.message}", response_body: response.body)
    end
  end
end
