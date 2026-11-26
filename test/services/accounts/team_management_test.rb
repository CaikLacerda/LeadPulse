require "test_helper"

module Accounts
  class TeamManagementTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @account = Account.create!(name: "Empresa A")
      @admin = create_member!(name: "Ana Admin", email: "ana@empresa-a.test", account: @account, role: "admin")
      @operator = create_member!(name: "Otto Operador", email: "otto@empresa-a.test", account: @account, role: "operator")
      @team = TeamManagement.new(account: @account, actor: @admin)
    end

    test "invites, supersedes the previous open invitation and sends the e-mail" do
      first = @team.invite(email: "nova@empresa.test", role: "viewer")
      second = nil
      assert_emails(1) { second = @team.invite(email: "Nova@empresa.test", role: "auditor") }

      assert first.success?
      assert second.success?
      assert first.record.reload.canceled_at.present?
      assert_equal [ second.record ], @account.account_invitations.open.to_a
      assert_equal "auditor", second.record.role
      assert_equal "account_member_invited", PrivacyAuditEvent.where(account: @account).order(:id).last.action
    end

    test "nobody changes their own role or removes themselves" do
      own = membership_of(@admin)

      assert_equal "Você não pode alterar o seu próprio papel.", @team.change_role(own, "viewer").error
      assert_equal "Você não pode remover a si mesmo da empresa.", @team.remove(own).error
      assert own.reload.admin?
    end

    test "the last active admin cannot be demoted by another admin either" do
      other_admin = create_member!(name: "Bia", email: "bia@empresa-a.test", account: @account, role: "admin")
      TeamManagement.new(account: @account, actor: other_admin).change_role(membership_of(@admin), "viewer")

      result = @team.change_role(membership_of(other_admin), "viewer")

      assert_not result.success?
      assert_equal "A empresa precisa de pelo menos um administrador ativo.", result.error
    end

    test "changes roles, removes and reactivates with audit events" do
      membership = membership_of(@operator)

      assert @team.change_role(membership, "manager").success?
      assert_equal "manager", membership.reload.role
      assert @team.remove(membership).success?
      assert membership.reload.disabled?
      assert User.exists?(@operator.id)
      assert @team.reactivate(membership).success?
      assert membership.reload.active?

      actions = PrivacyAuditEvent.where(account: @account).order(:id).pluck(:action).last(3)
      assert_equal %w[account_member_role_changed account_member_removed account_member_reactivated], actions
    end

    test "members without team permission cannot act" do
      team = TeamManagement.new(account: @account, actor: @operator)

      assert_not team.invite(email: "x@empresa.test", role: "admin").success?
      assert_not team.change_role(membership_of(@admin), "viewer").success?
      assert_equal 0, @account.account_invitations.count
    end
  end
end
