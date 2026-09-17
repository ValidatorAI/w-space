require "test_helper"

class Api::AttentionItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-attention-items-test", name: "Api Attention Items Test Project")
    @room = @project.rooms.create!(type: "Rooms::Project", name: "General", creator: users(:david))
    @attention_item = AttentionItem.create!(
      title: "Decision needed for API rollout",
      category: "decisions_waiting",
      status: :pending,
      user: users(:david),
      project: @project,
      room: @room,
      due_at: 1.day.from_now
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all attention items with a valid token" do
    second_item = AttentionItem.create!(
      title: "Follow up on launch review",
      category: "mentions",
      status: :pending,
      user: users(:jason),
      project: @project,
      room: @room,
      due_at: 2.days.from_now
    )

    get api_attention_items_url, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @attention_item.id, second_item.id ].sort, body["attention_items"].map { |item| item["id"] }.sort
  end

  test "paginates attention items when a page param is given" do
    second_item = AttentionItem.create!(
      title: "Follow up on launch review",
      category: "mentions",
      status: :pending,
      user: users(:jason),
      project: @project,
      room: @room,
      due_at: 2.days.from_now
    )

    get api_attention_items_url(page: 1, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal 1, body["page"]
    assert_equal 1, body["per_page"]
    assert_equal [ @attention_item.id ], body["attention_items"].map { |item| item["id"] }

    get api_attention_items_url(page: 2, per_page: 1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    assert_equal [ second_item.id ], JSON.parse(response.body)["attention_items"].map { |item| item["id"] }
  end

  test "filters attention items by optional fields and created_at range" do
    second_item = AttentionItem.create!(
      title: "Launch review",
      category: "mentions",
      status: :resolved,
      user: users(:jason),
      project: @project,
      room: @room,
      due_at: 2.days.from_now,
      created_at: 2.days.ago
    )

    older_item = AttentionItem.create!(
      title: "Old review",
      category: "mentions",
      status: :pending,
      user: users(:david),
      project: @project,
      room: @room,
      due_at: 5.days.from_now,
      created_at: 10.days.ago
    )

    get api_attention_items_url(
      category: "mentions",
      status: "resolved",
      created_at_gt: 3.days.ago.iso8601,
      created_at_lt: 1.day.ago.iso8601,
      page: 1,
      per_page: 10
    ), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ second_item.id ], body["attention_items"].map { |item| item["id"] }

    get api_attention_items_url(category: "mentions"), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ second_item.id, older_item.id ].sort, body["attention_items"].map { |item| item["id"] }.sort
  end

  test "creates an attention item with a valid token" do
    assert_difference -> { AttentionItem.count }, 1 do
      post api_attention_items_url,
        params: {
          title: "New decision item",
          category: "decisions_waiting",
          meta_text: "Needs approval",
          user_id: users(:jason).id,
          project_id: @project.id,
          room_id: @room.id,
          due_at: 3.days.from_now.iso8601
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New decision item", body["title"]
    assert_equal "decisions_waiting", body["category"]
    assert_equal users(:jason).id, body["user_id"]
    assert_equal @project.id, body["project_id"]
    assert_equal @room.id, body["room_id"]
  end

  test "rejects create requests without a token" do
    post api_attention_items_url,
      params: { title: "No token item", category: "decisions_waiting" }

    assert_response :unauthorized
  end

  test "updates an attention item with a valid token" do
    patch api_attention_item_url(@attention_item.id),
      params: {
        title: "Updated decision title",
        category: "blockers",
        meta_text: "Escalated for follow-up",
        status: "resolved",
        overdue: true,
        due_at: 1.day.from_now.iso8601
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Updated decision title", body["title"]
    assert_equal "blockers", body["category"]
    assert_equal "Escalated for follow-up", body["meta_text"]
    assert_equal "resolved", body["status"]
    assert_equal true, body["overdue"]
  end

  test "deletes an attention item with a valid token" do
    assert_difference -> { AttentionItem.count }, -1 do
      delete api_attention_item_url(@attention_item.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil AttentionItem.find_by(id: @attention_item.id)
  end

  test "rejects delete requests without a token" do
    delete api_attention_item_url(@attention_item.id)

    assert_response :unauthorized
  end

  test "rejects update requests without a token" do
    patch api_attention_item_url(@attention_item.id), params: { title: "No token update" }

    assert_response :unauthorized
  end

  test "returns an attention item with a valid token" do
    get api_attention_item_url(@attention_item.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @attention_item.id, body["id"]
    assert_equal @attention_item.category, body["category"]
    assert_equal @attention_item.title, body["title"]
  end

  test "rejects requests without a token" do
    get api_attention_item_url(@attention_item.id)

    assert_response :unauthorized
  end

  test "rejects requests with an invalid token" do
    get api_attention_item_url(@attention_item.id), headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "returns not found for an unknown attention item" do
    get api_attention_item_url(-1), headers: { "Authorization" => "Bearer test-token" }

    assert_response :not_found
  end
end
