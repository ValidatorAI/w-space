require "application_system_test_case"

class DirectContactsTest < ApplicationSystemTestCase
  test "filtering contacts and starting a Ping" do
    visit root_url
    fill_in "email_address", with: "david@37signals.com"
    fill_in "password", with: "secret123456"
    click_on "log_in"

    find("button[aria-label='Start a Ping']").click

    assert_selector "dialog.direct-contacts[open]"
    fill_in "Search contacts", with: "Bender"

    assert_selector "[data-direct-contacts-modal-search-value='bender bot']", visible: true
    assert_no_selector "[data-direct-contacts-modal-search-value='jason']", visible: true
    assert_no_selector "#direct-contacts-humans", visible: true

    previous_path = page.current_path
    find("[data-direct-contacts-modal-search-value='bender bot']").click

    assert_no_current_path previous_path
    assert_current_path %r{\A/rooms/\d+\z}
    room = Rooms::Direct.find(page.current_path.split("/").last)
    assert_equal [ users(:david).id, users(:bender).id ].sort, room.user_ids.sort
  end
end
