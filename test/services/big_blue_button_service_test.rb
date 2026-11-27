require "test_helper"

class BigBlueButtonServiceTest < ActiveSupport::TestCase
  test "create_meeting requests the BBB create endpoint" do
    response = Struct.new(:body).new(
      <<~XML
        <response>
          <returncode>SUCCESS</returncode>
          <messageKey>created</messageKey>
          <message>Meeting created.</message>
          <meetingID>room-123</meetingID>
        </response>
      XML
    )

    Net::HTTP.expects(:get_response).returns(response).once

    result = BigBlueButtonService.create_meeting(
      name: "Standup",
      meeting_id: "room-123",
      moderator_pw: "adminpass",
      attendee_pw: "memberpass"
    )

    assert_equal "SUCCESS", result[:returncode]
    assert_equal "room-123", result[:meetingID]
    assert_includes result[:request_url], "/api/create"
    assert_includes result[:request_url], "meetingID=room-123"
  end

  test "join_moderator and join_member build moderator and attendee join URLs" do
    response = Struct.new(:body).new(
      <<~XML
        <response>
          <returncode>SUCCESS</returncode>
          <messageKey>ok</messageKey>
          <message>user joined</message>
          <url>https://bbb.example.com/join/abc</url>
        </response>
      XML
    )

    Net::HTTP.expects(:get_response).returns(response).twice

    moderator_result = BigBlueButtonService.join_moderator(
      meeting_id: "room-123",
      full_name: "Alice Admin"
    )
    member_result = BigBlueButtonService.join_member(
      meeting_id: "room-123",
      full_name: "Bob Member"
    )

    assert_equal "SUCCESS", moderator_result[:returncode]
    assert_equal "SUCCESS", member_result[:returncode]
    assert_includes moderator_result[:request_url], "/api/join"
    assert_includes member_result[:request_url], "/api/join"
  end

  test "join requests expose the BBB API join URL as the redirect target" do
    redirect_response = Struct.new(:body, :headers) do
      def [](key)
        headers[key.to_s] || headers[key.to_sym]
      end
    end.new("", { "location" => "https://class.yogasina.com/html5client/join?sessionToken=abc123" })

    Net::HTTP.expects(:get_response).returns(redirect_response).once

    result = BigBlueButtonService.join_moderator(
      meeting_id: "room-123",
      full_name: "Alice Admin",
      password: "adminpass"
    )

    assert_includes result[:url], "/bigbluebutton/api/join"
    assert_includes result[:url], "meetingID=room-123"
    assert_includes result[:url], "fullName=Alice+Admin"
    assert_includes result[:url], "password=adminpass"
    assert_not_includes result[:url], "userID="
    assert_equal "https://class.yogasina.com/html5client/join?sessionToken=abc123", result[:location]
    assert_includes result[:request_url], "/api/join"
  end

  test "join requests omit userID for BBB join operations" do
    response = Struct.new(:body).new(
      <<~XML
        <response>
          <returncode>SUCCESS</returncode>
          <messageKey>ok</messageKey>
          <message>user joined</message>
          <url>https://bbb.example.com/join/abc</url>
        </response>
      XML
    )

    Net::HTTP.expects(:get_response).returns(response).once

    result = BigBlueButtonService.join_moderator(
      meeting_id: "room-123",
      full_name: "Alice Admin",
      password: "adminpass",
      user_id: "moderator-42"
    )

    assert_not_includes result[:request_url], "userID="
  end

  test "checksum signs the action and params before the shared secret" do
    original_secret = ENV["BBB_SECRET"]
    ENV["BBB_SECRET"] = "fTms153XMPu9iPiIOf6FYTfmBcuhvrfXXd0wEDTQ"

    query_string = "meetingID=room-123&name=Standup"
    expected = OpenSSL::Digest::SHA1.hexdigest("getMeetings#{query_string}#{ENV.fetch("BBB_SECRET")}")

    assert_equal expected, BigBlueButtonService.send(:checksum, "getMeetings", { name: "Standup", meetingID: "room-123" })
  ensure
    ENV["BBB_SECRET"] = original_secret
  end

  test "get_all_meetings exposes a list-meetings helper" do
    response = Struct.new(:body).new(
      <<~XML
        <response>
          <returncode>SUCCESS</returncode>
          <meetings>
            <meeting>
              <meetingID>room-123</meetingID>
              <meetingName>Standup</meetingName>
            </meeting>
          </meetings>
        </response>
      XML
    )

    Net::HTTP.expects(:get_response).returns(response).once

    result = BigBlueButtonService.get_all_meetings

    assert_equal "SUCCESS", result[:returncode]
    assert_includes result[:request_url], "/api/getMeetings"
  end
end
