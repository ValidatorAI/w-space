require "test_helper"

class HermesPromptBuilderTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "base_system_prompt enforces html formatting and room kanban guidelines" do
    prompt = Hermes::PromptBuilder.base_system_prompt
    assert_includes prompt, "For formatting do not use markup, you must use HTML tags"
    assert_includes prompt, "<pre>"
    assert_includes prompt, "use anban board per room"
  end

  test "build_space_event_message formats event correctly" do
    event_data = { "room_id" => 10, "text" => "Run analysis" }
    msg = Hermes::PromptBuilder.build_space_event_message("ai_question_asked", event_data)
    assert_match(/\ANew W-space event\n\(ai_question_asked\): \{.*"room_id":10.*\}\z/, msg)

    msg_no_type = Hermes::PromptBuilder.build_space_event_message(nil, event_data)
    assert_match(/\ANew W-space event\n\{.*"room_id":10.*\}\z/, msg_no_type)
  end

  test "build_attachment_summary formats url and message references" do
    attachments = [
      { filename: "doc.pdf", mime_type: "application/pdf", url: "https://example.com/doc.pdf" },
      { filename: "screen.png", mime_type: "image/png", message_id: 12, room_id: 3 }
    ]

    summary = Hermes::PromptBuilder.build_attachment_summary(attachments)
    assert_includes summary, "1. doc.pdf (application/pdf) -> https://example.com/doc.pdf"
    assert_includes summary, "2. screen.png (image/png) -> message_id=12, room_id=3"
  end

  test "extract_reply_text parses OpenAI choices payload" do
    payload = {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => "I can help with that."
          }
        }
      ]
    }
    assert_equal "I can help with that.", Hermes::PromptBuilder.extract_reply_text(payload)

    empty_payload = { "choices" => [] }
    assert_equal "", Hermes::PromptBuilder.extract_reply_text(empty_payload)
  end
end
