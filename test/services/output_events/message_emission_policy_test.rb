require "test_helper"

class OutputEvents::MessageEmissionPolicyTest < ActiveSupport::TestCase
  test "disallows bot-authored messages" do
    message = Message.new(room: rooms(:bender_and_kevin), creator: users(:bender), body: "Automated note")

    assert_not OutputEvents::MessageEmissionPolicy.allowed?(message: message)
  end

  test "disallows direct messages between two normal users" do
    message = Message.new(room: rooms(:david_and_kevin), creator: users(:david), body: "Private update")

    assert_not OutputEvents::MessageEmissionPolicy.allowed?(message: message)
  end

  test "allows user-authored direct messages when direct room includes a bot" do
    message = Message.new(room: rooms(:bender_and_kevin), creator: users(:kevin), body: "Please summarize")

    assert OutputEvents::MessageEmissionPolicy.allowed?(message: message)
  end

  test "allows non-direct user-authored messages" do
    message = Message.new(room: rooms(:watercooler), creator: users(:david), body: "Public update")

    assert OutputEvents::MessageEmissionPolicy.allowed?(message: message)
  end
end