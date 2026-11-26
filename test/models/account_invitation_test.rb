require "test_helper"

class AccountInvitationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "stores only the HMAC of a random token and finds by it" do
    invitation = build_invitation("Nova@Empresa.test ")
    token = invitation.regenerate_token
    invitation.save!

    assert_equal "nova@empresa.test", invitation.email
    assert_operator token.length, :>=, 40
    assert_not_equal token, invitation.token_digest
    assert_not_includes AccountInvitation.connection.select_value("SELECT row_to_json(i)::text FROM account_invitations i WHERE id = #{invitation.id}"), token
    assert_equal invitation, AccountInvitation.find_by_token(token)
    assert_nil AccountInvitation.find_by_token(token.reverse)
    assert_nil AccountInvitation.find_by_token(nil)
  end

  test "a new token replaces the previous one" do
    invitation = build_invitation("pessoa@empresa.test")
    old_token = invitation.regenerate_token
    invitation.save!
    new_token = invitation.regenerate_token
    invitation.save!

    assert_nil AccountInvitation.find_by_token(old_token)
    assert_equal invitation, AccountInvitation.find_by_token(new_token)
  end

  test "expires after the TTL" do
    invitation = build_invitation("pessoa@empresa.test")
    invitation.regenerate_token(now: 8.days.ago)
    invitation.save!

    assert_equal :expired, invitation.status
    assert_not_includes AccountInvitation.pending, invitation
  end

  test "cannot invite someone who is already an active member" do
    invitation = build_invitation(users(:one).email.upcase)
    invitation.regenerate_token

    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "já faz parte da empresa"
  end

  test "only one open invitation per e-mail in the account" do
    first = build_invitation("pessoa@empresa.test")
    first.regenerate_token
    first.save!
    second = build_invitation("PESSOA@empresa.test")
    second.regenerate_token

    assert_raises(ActiveRecord::RecordNotUnique) { second.save! }
  end

  private

  def build_invitation(email)
    @account.account_invitations.new(email: email, role: "operator", invited_by: users(:one))
  end
end
