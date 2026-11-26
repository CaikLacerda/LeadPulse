require "test_helper"

# Gestão de equipe de ponta a ponta: convite, cadastro ou login pelo link, papéis,
# remoção e isolamento entre empresas.
class TeamFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A", validation_company_name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B", validation_company_name: "Empresa B")
    @admin_a = create_member!(name: "Ana Admin", email: "ana@empresa-a.test", account: @account_a, role: "admin")
    @operator_a = create_member!(name: "Otto Operador", email: "otto@empresa-a.test", account: @account_a, role: "operator")
    @admin_b = create_member!(name: "Bruno Admin", email: "bruno@empresa-b.test", account: @account_b, role: "admin")
    @lot_a = create_analytics_batch!(account: @account_a, user: @admin_a, started_at: 1.day.ago)
  end

  test "a new person signs up from the invitation link and lands in the inviting company" do
    sign_in_as(@admin_a)
    assert_emails(1) do
      post team_invitations_url, params: { account_invitation: { email: "nova@pessoa.test", role: "auditor" } }
    end
    assert_redirected_to team_url
    link = flash[:invitation_link]
    assert_match %r{/convites/[\w-]{40,}\z}, link
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, URI(link).path
    sign_out_current

    get link
    assert_response :success
    assert_select "h1", text: "Convite para Empresa A"
    assert_select "a[href*='email=nova%40pessoa.test']", text: "Criar conta"

    assert_no_difference -> { Account.count } do
      post user_registration_url, params: { user: { name: "Nova Pessoa", email: "nova@pessoa.test", password: PASSWORD, password_confirmation: PASSWORD } }
    end
    newcomer = User.find_by!(email: "nova@pessoa.test")
    assert_equal [ [ @account_a.id, "auditor" ] ], newcomer.account_memberships.pluck(:account_id, :role)

    get supplier_imports_url
    assert_includes response.body, @lot_a.display_code

    get link
    assert_select "h1", text: "Convite já usado"
  end

  test "an existing user of another company signs in and accepts" do
    sign_in_as(@admin_a)
    post team_invitations_url, params: { account_invitation: { email: @admin_b.email, role: "viewer" } }
    link = flash[:invitation_link]
    sign_out_current

    get link
    post user_session_url, params: { user: { email: @admin_b.email, password: PASSWORD } }
    assert_redirected_to URI(link).path
    follow_redirect!
    assert_select "button", text: "Aceitar convite"

    assert_no_difference -> { User.count } do
      post URI(link).path + "/aceitar"
    end
    assert_redirected_to root_url
    assert_equal({ @account_a.id => "viewer", @account_b.id => "admin" }, @admin_b.account_memberships.pluck(:account_id, :role).to_h)

    get supplier_imports_url
    assert_includes response.body, @lot_a.display_code, "entra na empresa do convite"
  end

  test "an invitation for another e-mail cannot be accepted" do
    sign_in_as(@admin_a)
    post team_invitations_url, params: { account_invitation: { email: "alguem@pessoa.test", role: "admin" } }
    link = flash[:invitation_link]
    sign_out_current

    sign_in_as(@admin_b)
    get link
    assert_select ".workspace-callout", text: /este convite é para/
    post URI(link).path + "/aceitar"
    assert_not AccountMembership.exists?(account: @account_a, user: @admin_b)
  end

  test "invalid and expired tokens do not work" do
    get invitation_url("token-que-nao-existe")
    assert_select "h1", text: "Convite inválido"

    invitation = Accounts::TeamManagement.new(account: @account_a, actor: @admin_a).invite(email: "late@pessoa.test", role: "viewer")
    invitation.record.update!(expires_at: 1.hour.ago)
    get invitation_url(invitation.token)
    assert_select "h1", text: "Convite expirado"
  end

  test "admin changes roles and removes members; the operator only views the team" do
    sign_in_as(@admin_a)
    get team_url
    assert_select "td", text: /Otto Operador/
    assert_select "select[name='account_membership[role]']", count: 1, message: "só a linha do outro membro é editável"

    patch team_member_url(membership_of(@operator_a)), params: { account_membership: { role: "manager" } }
    assert_equal "manager", membership_of(@operator_a).reload.role

    patch team_member_url(membership_of(@admin_a)), params: { account_membership: { role: "viewer" } }
    assert_equal "Você não pode alterar o seu próprio papel.", flash[:alert]
    assert membership_of(@admin_a).reload.admin?

    delete team_member_url(membership_of(@operator_a))
    assert membership_of(@operator_a).reload.disabled?
    assert User.exists?(@operator_a.id)
    sign_out_current

    membership_of(@operator_a).reactivate!(role: "operator")
    sign_in_as(@operator_a)
    get team_url
    assert_response :success
    assert_select "select[name='account_membership[role]']", count: 0
    assert_select "button", text: "Convidar usuário", count: 0

    assert_no_difference -> { AccountInvitation.count } do
      post team_invitations_url, params: { account_invitation: { email: "x@pessoa.test", role: "admin" } }
    end
    patch team_member_url(membership_of(@operator_a)), params: { account_membership: { role: "admin" } }
    assert_equal "operator", membership_of(@operator_a).reload.role, "não ganha privilégio sozinho"
  end

  test "manipulated ids from another company return not found" do
    invitation = Accounts::TeamManagement.new(account: @account_a, actor: @admin_a).invite(email: "z@pessoa.test", role: "viewer").record
    sign_in_as(@admin_b)

    [
      [ :patch, team_member_url(membership_of(@operator_a)), { account_membership: { role: "admin" } } ],
      [ :delete, team_member_url(membership_of(@operator_a)) ],
      [ :patch, reactivate_team_member_url(membership_of(@operator_a)) ],
      [ :post, resend_team_invitation_url(invitation) ],
      [ :delete, team_invitation_url(invitation) ]
    ].each do |method, url, params|
      public_send(method, url, params: params || {})
      assert_response :not_found, "#{method} #{url}"
    end

    get team_url
    assert_not_includes response.body, "Otto Operador"
    assert_not_includes response.body, "z@pessoa.test"
    assert membership_of(@operator_a).reload.active?
    assert_nil invitation.reload.canceled_at
  end

  private

  def sign_in_as(user)
    post user_session_url, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_out_current
    delete destroy_user_session_url
  end
end
