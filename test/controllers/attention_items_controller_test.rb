require "test_helper"

class AttentionItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @attention_item = AttentionItem.create!(
      title: "Approve smart contract audit",
      category: "decisions_waiting",
      status: :pending
    )
  end

  test "resolves attention item via patch resolve" do
    assert_difference -> { OutputEvent.count }, +1 do
      patch resolve_attention_item_url(@attention_item), as: :json
      assert_response :success
    end

    @attention_item.reload
    assert @attention_item.resolved?
    assert_equal users(:david), @attention_item.resolved_by

    event = OutputEvent.order(:id).last
    assert_equal "decision_waiting_resolved", event.event_type
    assert_equal @attention_item.id, event.event_id
    assert_equal "AttentionItem", event.event_data["target_type"]
    assert_equal "decisions_waiting", event.event_data["category"]
    assert_equal "resolved", event.event_data["status"]
    assert_equal @attention_item.title, event.event_data["content"]
    assert_equal "attention_item_resolution", event.event_data.dig("content_payload", "type")
  end

  test "dismisses attention item via patch dismiss" do
    patch dismiss_attention_item_url(@attention_item), as: :json
    assert_response :success

    @attention_item.reload
    assert @attention_item.dismissed?
    assert_equal users(:david), @attention_item.resolved_by
  end

  test "resolves attention item via update status" do
    patch attention_item_url(@attention_item), params: { status: "resolved" }, as: :json
    assert_response :success

    @attention_item.reload
    assert @attention_item.resolved?
  end

  test "category-based event type falls back to generic name" do
    item = AttentionItem.create!(title: "Generic work item", status: :pending)

    assert_difference -> { OutputEvent.count }, +1 do
      patch resolve_attention_item_url(item), as: :json
      assert_response :success
    end

    event = OutputEvent.order(:id).last
    assert_equal "attention_item_resolved", event.event_type
    assert_equal item.id, event.event_id
  end
end
