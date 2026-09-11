require "net/http"
require "uri"
require "securerandom"

module OutputEvents
  class DeliveryClient
    ENDPOINT_TIMEOUT = 7.seconds

    class PermanentDeliveryError < StandardError; end
    class TransientDeliveryError < StandardError; end

    def deliver(event)
      response = http(uri).request(request(event))
      return if response.is_a?(Net::HTTPSuccess)

      error_class = response.code.to_i >= 500 ? TransientDeliveryError : PermanentDeliveryError
      raise error_class, "Output event delivery returned HTTP #{response.code}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => error
      raise TransientDeliveryError, error.message
    end

    private
      def uri
        @uri ||= URI(ENV.fetch("OUTPUT_EVENTS_URL"))
      end

      def http(destination)
        Net::HTTP.new(destination.host, destination.port).tap do |connection|
          connection.use_ssl = destination.scheme == "https"
          connection.open_timeout = ENDPOINT_TIMEOUT
          connection.read_timeout = ENDPOINT_TIMEOUT
        end
      end

      def request(event)
        return multipart_request(event) if file_event?(event)

        json_request(event)
      end

      def json_request(event)
        Net::HTTP::Post.new(uri, headers.merge("Content-Type" => "application/json")).tap do |post|
          post.body = payload(event).to_json
        end
      end

      def multipart_request(event)
        attachment = attachment_for(event)
        return json_request(event) unless attachment

        boundary = "----bonfire-output-events-#{SecureRandom.hex(12)}"
        body = multipart_body(boundary: boundary, payload_json: payload(event).to_json, attachment: attachment)

        Net::HTTP::Post.new(uri, headers.merge("Content-Type" => "multipart/form-data; boundary=#{boundary}")).tap do |post|
          post.body = body
        end
      end

      def headers
        { "Content-Type" => "application/json" }.tap do |headers|
          token = ENV["OUTPUT_EVENTS_TOKEN"].presence
          headers["Authorization"] = "Bearer #{token}" if token
        end
      end

      def payload(event)
        {
          id: event.id,
          event_type: event.event_type,
          event_id: event.event_id,
          group_id: event.group_id,
          event_data: event.event_data,
          created_at: event.created_at.iso8601
        }
      end

      def file_event?(event)
        event.event_type.to_s == "message_attachment_uploaded"
      end

      def attachment_for(event)
        message = Message.find_by(id: event.event_id)
        return unless message&.attachment?

        {
          filename: message.attachment.filename.to_s,
          content_type: message.attachment.content_type.presence || "application/octet-stream",
          bytes: message.attachment.download
        }
      end

      def multipart_body(boundary:, payload_json:, attachment:)
        body = +""
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"event\"\r\n"
        body << "Content-Type: application/json\r\n\r\n"
        body << payload_json
        body << "\r\n"

        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{attachment[:filename]}\"\r\n"
        body << "Content-Type: #{attachment[:content_type]}\r\n\r\n"
        body << attachment[:bytes]
        body << "\r\n"

        body << "--#{boundary}--\r\n"
      end
  end
end