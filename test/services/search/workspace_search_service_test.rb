require "test_helper"

class Searches::WorkspaceSearchServiceTest < ActiveSupport::TestCase
  test "fuzzy workspace search matches room and message data and sorts newest first" do
    room = rooms(:designers)
    room.update!(name: "Revenue planning room")

    older_message = room.messages.create!(body: "The team reviewed last quarter revenue", client_message_id: "old-revenue", creator: users(:david))
    newer_message = room.messages.create!(body: "Latest revenue forecast is up 12%", client_message_id: "new-revenue", creator: users(:david))

    results = Searches::WorkspaceSearchService.new(user: users(:david), query: "revenue", page: 1, per_page: 10).call

    assert_operator results.size, :>=, 2
    assert_includes results.map { |result| result[:title] }, "Revenue planning room"
    assert_includes results.map { |result| result[:title] }, "Latest revenue forecast is up 12%"
    assert_operator results.index { |result| result[:title] == "Latest revenue forecast is up 12%" }, :<, results.index { |result| result[:title] == "The team reviewed last quarter revenue" }
  end

  test "preview is limited to five results" do
    room = rooms(:designers)

    6.times do |index|
      room.messages.create!(body: "Revenue search result #{index}", client_message_id: "preview-#{index}", creator: users(:david))
    end

    results = Searches::WorkspaceSearchService.new(user: users(:david), query: "revenue", page: 1, per_page: 5).call

    assert_equal 5, results.size
  end
end
