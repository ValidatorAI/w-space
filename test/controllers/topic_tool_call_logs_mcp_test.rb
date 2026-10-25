require "test_helper"

class TopicToolCallLogsMcpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Mcp.load_tools!
    @user = User.create!(name: "Topic Log User", display_name: "Topic Log User", email_address: "topic-log-#{SecureRandom.hex(4)}@example.com", password: "Password123!", password_confirmation: "Password123!", role: :member)
    @project = Project.find_or_create_by!(path: "topic-log-project-#{SecureRandom.hex(4)}") do |project|
      project.name = "Topic Log Project"
      project.slug = "topic-log-project-#{SecureRandom.hex(4)}"
    end
    @room = Room.create!(type: "Rooms::Open", name: "Topic Log Room", project: @project, creator: @user)
    @topic = Topic.create!(name: "Topic Log Topic", project: @project)
  end

  def call_tool(endpoint, tool_name, arguments = {})
    post endpoint,
         params: {
           jsonrpc: "2.0",
           id: "test_#{tool_name}",
           method: "tools/call",
           params: { name: tool_name, arguments: arguments }
         }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success, "Expected #{endpoint} to dispatch #{tool_name}"
    response.parsed_body
  end

  test "create_topic_tool_call_log persists and read-mcp filters logs by topic, room, project, and date" do
    start_datetime = Time.current
    payload = call_tool("/action-mcp", "create_topic_tool_call_log",
                        {
                          topic_id: @topic.id,
                          room_id: @room.id,
                          project_id: @project.id,
                          created_date: start_datetime.iso8601,
                          used_tool_name: "create_topic",
                          target_entity_id: @topic.id,
                          change_log: "Created topic record",
                          why_was_it_required: "Needed to preserve the action history"
                        })

    assert_equal false, payload.dig("result", "isError"), payload.inspect
    created = TopicToolCallLog.order(:id).last
    assert_equal @topic.id, created.topic_id
    assert_equal @room.id, created.room_id
    assert_equal @project.id, created.project_id
    assert_equal "create_topic", created.used_tool_name

    read_payload = call_tool("/read-mcp", "topic_tool_call_logs",
                            {
                              topic_id: @topic.id,
                              room_id: @room.id,
                              project_id: @project.id,
                              start_date: start_datetime.to_date.iso8601,
                              end_date: start_datetime.to_date.iso8601
                            })

    assert_equal false, read_payload.dig("result", "isError"), read_payload.inspect
    body = read_payload.dig("result", "content", 0, "text").to_s
    assert_includes body, "Created topic record"
    assert_includes body, "create_topic"
  end
end
