require "test_helper"

class ApprovalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @room = rooms(:designers)
    @message = messages(:first)
  end

  test "validates payload must be object" do
    request = ApprovalRequest.new(room: @room, payload: "not a hash")
    assert_not request.valid?

    request.payload = { "decision" => "Use ERC-4337 router pattern" }
    assert request.valid?
  end

  test "approve! transitions status and creates audit record" do
    request = ApprovalRequest.create!(
      room: @room,
      message: @message,
      request_type: "decision",
      payload: { "decision" => "Use ERC-4337 router pattern" },
      status: :pending
    )

    assert request.pending?
    assert_equal 0, request.approval_request_actions.count

    request.approve!(@user, note: "Looks good to me")

    assert request.approved?
    assert_equal @user, request.resolved_by
    assert_not_nil request.resolved_at
    assert_equal 1, request.approval_request_actions.count

    action = request.approval_request_actions.first
    assert_equal "approve", action.action
    assert_equal @user, action.actor
    assert_equal "Looks good to me", action.note
  end

  test "confirm! transitions status to approved with confirm action" do
    request = ApprovalRequest.create!(
      room: @room,
      message: @message,
      request_type: "decision",
      payload: { "decision" => "Use gas optimization pattern" },
      status: :pending
    )

    request.confirm!(@user)

    assert request.approved?
    action = request.approval_request_actions.first
    assert_equal "confirm", action.action
  end

  test "deny! transitions status to denied" do
    request = ApprovalRequest.create!(
      room: @room,
      message: @message,
      request_type: "workflow",
      payload: { "task" => "Deploy without review" },
      status: :pending
    )

    request.deny!(@user, note: "Need audit first")

    assert request.denied?
    assert_equal 1, request.approval_request_actions.count
    assert_equal "deny", request.approval_request_actions.first.action
  end

  test "resolves linked attention items on approval" do
    request = ApprovalRequest.create!(
      room: @room,
      message: @message,
      request_type: "decision",
      payload: { "decision" => "Update staking contract" },
      status: :pending
    )

    attention_item = AttentionItem.create!(
      title: "Decision on staking contract",
      category: "decisions_waiting",
      status: :pending,
      source: request
    )

    assert attention_item.pending?
    request.confirm!(@user)

    attention_item.reload
    assert attention_item.resolved?
    assert_equal @user, attention_item.resolved_by
  end

  test "approve! creates a project adr and links it to the originating room" do
    project = Project.create!(path: "/tmp/approval-request-room-decision-#{SecureRandom.uuid}", name: "Room Decision Project")
    room = project.rooms.create!(type: "Rooms::Project", name: "General", creator: @user)
    request = ApprovalRequest.create!(
      room: room,
      message: @message,
      request_type: "decision",
      payload: { "decision" => "Ship the W-space beta" },
      status: :pending
    )

    request.approve!(@user, note: "Approved")

    adr = project.adrs.order(:created_at).last
    assert_not_nil adr
    assert_equal "Ship the W-space beta", adr.title
    assert_includes room.project_adrs, adr
    assert_equal 1, DecisionRoom.where(room: room, project_adr: adr).count
  end
end
