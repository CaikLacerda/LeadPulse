require "test_helper"
require "csv"

# Matriz de papéis: cada papel da empresa, em cada página e ação relevante. O esperado vem
# direto das permissões do vínculo (AccountMembership#can_*).
class RolePermissionsTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD
  ROLES = AccountMembership::ROLES.keys

  setup do
    @account = Account.create!(name: "Empresa de papéis", validation_company_name: "Empresa de papéis")
    @owner = create_member!(name: "Dona", email: "dona@papeis.test", account: @account, role: "admin")
    @lot = create_analytics_batch!(account: @account, user: @owner, started_at: 1.day.ago, result_ready: true,
      records: analytics_records(confirmed: 2, not_answered: 1))
  end

  test "pages follow the role permissions" do
    ROLES.each do |role|
      member = member_with(role)
      permissions = membership_of(member)
      sign_in_as(member)

      {
        root_path => true,
        supplier_imports_path => true,
        supplier_import_path(@lot) => permissions.can_view_evidence?,
        supplier_discovery_searches_path => true,
        commercial_opportunities_path => true,
        validation_audits_path => permissions.can_view_evidence?,
        analytics_path => true,
        calls_analytics_path => true,
        qualification_analytics_path => true,
        batches_analytics_path => true,
        team_path => true,
        company_platform_settings_path => permissions.can_manage_settings?,
        twilio_platform_settings_path => permissions.can_manage_settings?,
        analytics_api_tokens_path => permissions.can_manage_bi_tokens?,
        lgpd_platform_settings_path => permissions.can_manage_lgpd?,
        privacy_audit_events_path => permissions.can_manage_lgpd?,
        developer_docs_path => true
      }.each do |path, allowed|
        get path
        if allowed
          assert_response :success, "#{role} deveria abrir #{path}"
        else
          assert_response :redirect, "#{role} não deveria abrir #{path}"
        end
      end

      sign_out_current
    end
  end

  test "actions follow the role permissions" do
    ROLES.each do |role|
      member = member_with(role)
      permissions = membership_of(member)
      lot = create_analytics_batch!(account: @account, user: @owner, started_at: 1.day.ago, result_ready: true, records: analytics_records(confirmed: 1))
      sign_in_as(member)

      get export_result_supplier_import_path(lot)
      assert_equal permissions.can_export_data?, response.media_type == "text/csv", "#{role}: CSV do lote"

      get export_analytics_path(format: :csv, conjunto: "registros")
      assert_equal permissions.can_export_data?, response.media_type == "text/csv", "#{role}: CSV do Analytics"

      get export_analytics_path(format: :xlsx)
      assert_response :success, "#{role}: XLSX do Analytics (agregados) é de todos"

      assert_difference -> { @account.account_invitations.count }, permissions.can_manage_team? ? 1 : 0 do
        post team_invitations_path, params: { account_invitation: { email: "convite-#{role}@papeis.test", role: "viewer" } }
      end

      assert_difference -> { @account.analytics_api_tokens.count }, permissions.can_manage_bi_tokens? ? 1 : 0 do
        post analytics_api_tokens_path, params: { analytics_api_token: { name: "Token #{role}" } }
      end

      post anonymize_evidence_supplier_import_path(lot)
      assert_equal permissions.can_anonymize_evidence?, lot.reload.evidence_anonymized?, "#{role}: anonimizar evidências"

      events_before = PrivacyAuditEvent.where(supplier_import_id: lot.id).count
      delete supplier_import_path(lot)
      assert_equal permissions.can_import_data?, !SupplierImport.exists?(lot.id), "#{role}: excluir lote"
      if permissions.can_import_data? && events_before.positive?
        assert_equal events_before, PrivacyAuditEvent.where(resource_type: "SupplierImport", resource_id: lot.id.to_s).count + PrivacyAuditEvent.where(supplier_import_id: lot.id).count,
          "#{role}: a trilha LGPD do lote continua depois da exclusão"
        assert PrivacyAuditEvent.exists?(action: "supplier_import_deleted", performed_by: member)
      end

      sign_out_current
    end
  end

  test "nobody gains privileges by changing their own role" do
    (ROLES - [ "admin" ]).each do |role|
      member = member_with(role)
      membership = membership_of(member)
      sign_in_as(member)

      patch team_member_path(membership), params: { account_membership: { role: "admin" } }
      assert_equal role, membership.reload.role, role

      sign_out_current
    end
  end

  private

  def member_with(role)
    create_member!(name: "Pessoa #{role}", email: "#{role}-#{SecureRandom.hex(3)}@papeis.test", account: @account, role: role)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_out_current
    delete destroy_user_session_path
  end
end
