require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a name" do
    user = User.new(email: "sem-nome@example.com", password: "Password123!")

    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "belongs to accounts through memberships" do
    assert_equal [ accounts(:one) ], users(:one).accounts.to_a
    assert_equal "admin", users(:one).account_memberships.first.role
  end
end
