require "test_helper"

class CompanyStatusToolsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "creates company status period and adds priority items" do
    add_period = Mcp::Registry.find_tool("add_company_status_period", scope: :action)
    res = add_period.call(name: "Q4 2026", slug: "q4-2026", current: true)
    assert_equal false, res[:isError]

    period = CompanyStatusPeriod.find_by!(slug: "q4-2026")
    assert period.current?

    priorities_tool = Mcp::Registry.find_tool("priorities", scope: :action)
    res_p = priorities_tool.call(
      company_status_period_id: period.id,
      title: "Deliver Native MCP",
      summary: "Port W-bridge to Rails",
      status: "on_track",
      badge: "green"
    )
    assert_equal false, res_p[:isError]

    item = CompanyStatusItem.last
    assert_equal "priorities", item.category
    assert_equal "Deliver Native MCP", item.title

    # Read
    read_p = Mcp::Registry.find_tool("priorities", scope: :read)
    res_list = read_p.call(company_status_period_id: period.id)
    assert_equal false, res_list[:isError]
    assert_includes res_list[:content].first[:text], "Deliver Native MCP"
  end
end
