require "test_helper"

module Accounts
  class AcceptInvitationTest < ActiveSupport::TestCase
    setup do
      @account = Account.create!(name: "Empresa A")
      @admin = create_member!(name: "Ana", email: "ana@empresa-a.test", account: @account, role: "admin")
      @guest = User.create!(name: "Caio", email: "caio@pessoal.test", password: "Password123!", password_confirmation: "Password123!")
    end

    test "creates an active membership with the invited role, once" do
      invitation = invite("caio@pessoal.test", "auditor")

      result = AcceptInvitation.new(invitation: invitation, user: @guest).call

      assert result.success?
      assert_equal @account, result.membership.account
      assert_equal "auditor", result.membership.role
      assert_equal @admin, result.membership.invited_by
      assert invitation.reload.accepted_at.present?
      assert_equal "account_member_joined", PrivacyAuditEvent.where(account: @account).last.action

      again = AcceptInvitation.new(invitation: invitation, user: @guest).call
      assert_equal "Este convite já foi usado.", again.error
    end

    test "an existing user joins a second account without a new user" do
      other_account = Account.create!(name: "Empresa B")
      AccountMembership.create!(account: other_account, user: @guest, role: "admin")

      assert_no_difference -> { User.count } do
        assert AcceptInvitation.new(invitation: invite("caio@pessoal.test", "viewer"), user: @guest).call.success?
      end
      assert_equal({ "Empresa A" => "viewer", "Empresa B" => "admin" }, @guest.account_memberships.includes(:account).to_h { |membership| [ membership.account.name, membership.role ] })
    end

    test "refuses expired, canceled and other e-mail invitations" do
      expired = invite("caio@pessoal.test", "viewer")
      expired.update!(expires_at: 1.minute.ago)
      assert_match "expirou", AcceptInvitation.new(invitation: expired, user: @guest).call.error

      canceled = invite("outra@pessoal.test", "viewer")
      canceled.update!(canceled_at: Time.current)
      assert_equal "Este convite foi cancelado.", AcceptInvitation.new(invitation: canceled, user: @guest).call.error

      someone_else = invite("outra2@pessoal.test", "viewer")
      assert_equal "Este convite foi enviado para outro e-mail.", AcceptInvitation.new(invitation: someone_else, user: @guest).call.error
      assert_not AccountMembership.exists?(account: @account, user: @guest)
    end

    test "reactivates a disabled membership with the new role" do
      membership = AccountMembership.create!(account: @account, user: @guest, role: "operator", status: AccountMembership::STATUS_DISABLED)

      result = AcceptInvitation.new(invitation: invite("caio@pessoal.test", "manager"), user: @guest).call

      assert result.success?
      assert_equal membership.id, result.membership.id
      assert membership.reload.active?
      assert_equal "manager", membership.role
    end

    private

    def invite(email, role)
      TeamManagement.new(account: @account, actor: @admin).invite(email: email, role: role).record
    end
  end
end
