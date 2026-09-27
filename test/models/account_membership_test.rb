require "test_helper"

class AccountMembershipTest < ActiveSupport::TestCase
  PERMISSIONS = {
    "admin" => %i[
      can_manage_lgpd? can_manage_settings? can_manage_team? can_manage_bi_tokens? can_import_data?
      can_start_validation? can_export_data? can_view_evidence? can_anonymize_evidence?
    ],
    "manager" => %i[can_import_data? can_start_validation? can_export_data? can_view_evidence?],
    "operator" => %i[can_start_validation? can_view_evidence?],
    "auditor" => %i[can_export_data? can_view_evidence?],
    "viewer" => []
  }.freeze
  ALL_PERMISSIONS = PERMISSIONS["admin"]

  test "each role grants exactly its permissions" do
    PERMISSIONS.each do |role, granted|
      membership = AccountMembership.new(role: role)

      ALL_PERMISSIONS.each do |permission|
        assert_equal granted.include?(permission), membership.public_send(permission),
          "#{role} #{permission} deveria ser #{granted.include?(permission)}"
      end
    end
  end

  test "rejects unknown roles" do
    membership = AccountMembership.new(account: Account.new(name: "Empresa"), user: users(:one), role: "owner")

    assert_not membership.valid?
    assert membership.errors.of_kind?(:role, :inclusion)
  end

  test "a user joins the same account only once" do
    account = Account.create!(name: "Empresa ABC")
    AccountMembership.create!(account:, user: users(:one), role: "admin")

    duplicate = AccountMembership.new(account:, user: users(:one), role: "viewer")

    assert_not duplicate.valid?
  end

  test "the last active admin cannot lose the role, be disabled or be deleted" do
    account = Account.create!(name: "Empresa com um admin")
    admin = AccountMembership.create!(account:, user: users(:one), role: "admin")

    assert_not admin.update(role: "viewer")
    assert_includes admin.errors[:base], "A empresa precisa de pelo menos um administrador ativo."
    admin.reload
    assert_not admin.update(status: AccountMembership::STATUS_DISABLED)
    assert_not admin.reload.destroy
    assert AccountMembership.exists?(admin.id)
  end

  test "an admin can step down when another active admin exists" do
    account = Account.create!(name: "Empresa com dois admins")
    first = AccountMembership.create!(account:, user: users(:one), role: "admin")
    second = AccountMembership.create!(account:, user: users(:two), role: "admin")

    assert first.update(role: "manager")
    assert_not second.reload.update(role: "viewer"), "o segundo virou o último admin ativo"
  end

  test "a disabled admin does not count as the account admin" do
    account = Account.create!(name: "Empresa")
    active = AccountMembership.create!(account:, user: users(:one), role: "admin")
    AccountMembership.create!(account:, user: users(:two), role: "admin", status: AccountMembership::STATUS_DISABLED)

    assert active.last_active_admin?
  end

  test "disabling keeps the user and marks when it happened" do
    account = Account.create!(name: "Empresa")
    AccountMembership.create!(account:, user: users(:one), role: "admin")
    member = AccountMembership.create!(account:, user: users(:two), role: "operator")

    member.disable!

    assert member.disabled?
    assert member.disabled_at.present?
    assert User.exists?(users(:two).id)
    assert_equal [ users(:one) ], account.account_memberships.active.map(&:user)
  end

  test "the database refuses unknown roles and statuses" do
    membership = AccountMembership.create!(account: Account.create!(name: "Empresa"), user: users(:one), role: "admin")

    assert_raises(ActiveRecord::StatementInvalid) { membership.update_columns(role: "owner") }
    assert_raises(ActiveRecord::StatementInvalid) { membership.update_columns(status: "pending") }
  end
end
