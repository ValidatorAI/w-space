require "test_helper"

class Users::Projects::ActionItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @project = Project.create!(
      name: "B2B Crypto Platform",
      path: "/tmp/b2b-crypto-#{SecureRandom.hex(4)}",
      description: "Platform specs"
    )
    @project.project_users.create!(user: users(:david))
    @action_item = @project.project_all_hands_action_items.create!(
      title: "Finalize Multi-sig threshold logic",
      assignee_name: "Alex",
      due_date: "Aug 25",
      completed: false
    )
  end

  test "toggle updates action item to completed with turbo stream and broadcasts update" do
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      @project, :all_hands,
      target: "all_hands_action_items_card",
      partial: "users/projects/all_hands/action_items_card",
      locals: { action_items: [@action_item], project: @project }
    ).once

    patch user_company_project_action_item_toggle_url(project_id: @project.id, id: @action_item.id), as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="replace" target="all_hands_action_items_card"), @response.body
    assert_match "Finalize Multi-sig threshold logic", @response.body
    assert_match "All Complete", @response.body
    assert @action_item.reload.completed?
  end

  test "toggle updates action item to completed with html redirect" do
    patch user_company_project_action_item_toggle_url(project_id: @project.id, id: @action_item.id)

    assert_redirected_to user_company_project_all_hands_url(id: @project.id)
    assert @action_item.reload.completed?
  end

  test "toggle returns not found for non-member user" do
    other_user = users(:kevin)
    sign_in other_user

    assert_raises(ActiveRecord::RecordNotFound) do
      patch user_company_project_action_item_toggle_url(project_id: @project.id, id: @action_item.id)
    end
  end
end
