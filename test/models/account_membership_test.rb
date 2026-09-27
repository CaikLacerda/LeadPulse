require "test_helper"

class AccountMembershipTest < ActiveSupport::TestCase
  PERMISSIONS = {
    "admin" => %i[can_manage_lgpd? can_manage_settings? can_import_data? can_start_validation? can_export_data? can_view_evidence? can_anonymize_evidence?],
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
end
