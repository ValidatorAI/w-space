require "test_helper"

class McpFuzzyMatcherTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      name: "alice",
      display_name: "Alice Wonderland",
      email_address: "alice@example.com",
      role: :member
    )
    @bot = User.create!(
      name: "coder_bot",
      display_name: "Coder Bot",
      email_address: "coder_bot@example.com",
      role: :bot
    )
    @project = Project.create!(
      name: "Alpha Project",
      path: "/path/to/alpha",
      slug: "alpha-project"
    )
    @room = Rooms::Open.create!(
      creator: @user,
      project: @project,
      name: "Development Room"
    )
  end

  test "normalizes text and calculates similarity score" do
    assert_equal "alpha project", Mcp::FuzzyMatcher.normalize_text("  Alpha-Project! ")
    assert_equal 1.0, Mcp::FuzzyMatcher.similarity_score("alpha", "alpha")
    assert Mcp::FuzzyMatcher.similarity_score("alpha", "alpha project") >= 0.9
    assert Mcp::FuzzyMatcher.similarity_score("xyz", "abc") < 0.4
  end

  test "matches project by ID and fuzzy name" do
    assert_equal @project, Mcp::FuzzyMatcher.match_project(@project.id)
    assert_equal @project, Mcp::FuzzyMatcher.match_project("Alpha")
    assert_equal @project, Mcp::FuzzyMatcher.match_project("alpha project")
    assert_nil Mcp::FuzzyMatcher.match_project("NonExistentProjectXYZ")
  end

  test "matches room by ID and fuzzy name" do
    assert_equal @room, Mcp::FuzzyMatcher.match_room(@room.id)
    assert_equal @room, Mcp::FuzzyMatcher.match_room("Development")
    assert_equal @room, Mcp::FuzzyMatcher.match_room("development room", project_id: @project.id)
    assert_nil Mcp::FuzzyMatcher.match_room("Unknown Room")
  end

  test "matches user by ID and fuzzy name or email" do
    assert_equal @user, Mcp::FuzzyMatcher.match_user(@user.id)
    assert_equal @user, Mcp::FuzzyMatcher.match_user("alice")
    assert_equal @user, Mcp::FuzzyMatcher.match_user("Alice Wonderland")
    assert_equal @user, Mcp::FuzzyMatcher.match_user("alice@example.com")
    assert_nil Mcp::FuzzyMatcher.match_user("NobodyHere")
  end

  test "matches bot by ID and name" do
    assert_equal @bot, Mcp::FuzzyMatcher.match_bot(@bot.id)
    assert_equal @bot, Mcp::FuzzyMatcher.match_bot("coder_bot")
    assert_equal @bot, Mcp::FuzzyMatcher.match_bot("Coder Bot")
    assert_nil Mcp::FuzzyMatcher.match_bot("non_existent_bot")
  end
end
