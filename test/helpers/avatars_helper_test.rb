require "test_helper"

class AvatarsHelperTest < ActionView::TestCase
  UserStub = Struct.new(:id, :title) do
    def to_param
      id.to_s
    end
  end

  setup do
    Current.user = UserStub.new(42, "Current User")
    helper.singleton_class.define_method(:fresh_user_avatar_path) { |*_args| "/avatar" }
  end

  test "current user avatar links to settings" do
    html = avatar_tag(Current.user)

    assert_select_in_html html, "a[href='/users/me/settings']", count: 1
  end

  test "other user avatar links to profile page" do
    other_user = UserStub.new(99, "Other User")

    html = avatar_tag(other_user)

    assert_select_in_html html, "a[href='#{user_path(other_user)}']", count: 1
  end
end
