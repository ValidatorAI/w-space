require "test_helper"

class FirstRunTest < ActiveSupport::TestCase
  setup do
    Account.destroy_all
    Room.destroy_all
    User.destroy_all
  end

  test "creating makes first user an administrator" do
    user = create_first_run_user
    assert user.administrator?
  end

  test "first user does not create an automatic room" do
    user = create_first_run_user
    assert_equal 0, user.rooms.count
    assert_nil Room.first
  end

  private
    def create_first_run_user
      FirstRun.create!({ name: "User", email_address: "user@example.com", password: "secret123456" })
    end
end
