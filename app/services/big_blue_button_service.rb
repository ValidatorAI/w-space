require "cgi"
require "net/http"
require "openssl"
require "uri"

class BigBlueButtonService
  class << self
    def create_meeting(name:, meeting_id:, moderator_pw: nil, attendee_pw: nil, record: false, welcome: nil, **extra)
      params = {
        name: name,
        meetingID: meeting_id,
        moderatorPW: moderator_pw.presence || moderator_password,
        attendeePW: attendee_pw.presence || attendee_password,
        record: record ? "true" : "false"
      }
      params[:welcome] = welcome if welcome.present?
      params.merge!(extra)

      request(:create, params)
    end

    def join_moderator(meeting_id:, full_name:, user_id: nil, password: nil, **extra)
      params = {
        meetingID: meeting_id,
        fullName: full_name,
        password: password.presence || moderator_password
      }
      params[:userID] = user_id if user_id.present?
      params.merge!(extra)

      request(:join, params)
    end

    def join_member(meeting_id:, full_name:, user_id: nil, password: nil, **extra)
      params = {
        meetingID: meeting_id,
        fullName: full_name,
        password: password.presence || attendee_password
      }
      params[:userID] = user_id if user_id.present?
      params.merge!(extra)

      request(:join, params)
    end

    def get_meetings
      request(:getMeetings, {})
    end
    alias_method :get_all_meetings, :get_meetings

    private
      def request(action, params)
        uri = build_uri(action, params)
        response = Net::HTTP.get_response(uri)
        result = if response.body.present?
          parsed = Hash.from_xml(response.body).deep_symbolize_keys
          parsed = parsed[:response] if parsed.key?(:response)
          parsed
        else
          {}
        end
        result[:request_url] = uri.to_s
        result
      end

      def build_uri(action, params)
        url = server_url
        uri = URI.parse(url)
        base_path = uri.path.to_s.sub(%r{/*\z}, "")
        uri.path = "#{base_path}/api/#{action}"
        uri.query = URI.encode_www_form(sorted_params(params).merge(checksum: checksum(action, params)))
        uri
      end

      def sorted_params(params)
        params.to_h.sort_by { |key, _| key.to_s }.to_h
      end

      def checksum(action, params)
        query_string = sorted_params(params)
          .map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }
          .join("&")

        OpenSSL::Digest::SHA1.hexdigest("#{bbb_secret}#{action}#{query_string}")
      end

      def server_url
        ENV.fetch("BBB_SERVER", "https://bigbluebutton.example.com/bigbluebutton/")
      end

      def bbb_secret
        ENV.fetch("BBB_SECRET", "")
      end

      def moderator_password
        ENV.fetch("BBB_MODERATOR_PASSWORD", "admin")
      end

      def attendee_password
        ENV.fetch("BBB_ATTENDEE_PASSWORD", "member")
      end
  end
end
