require "test_helper"

# Uma pessoa em duas empresas: escolhe em qual trabalha e só vê os dados dela.
class AccountSelectionTest < ActionDispatch::IntegrationTest
  setup do
    @account_a = Account.create!(name: "Empresa A", validation_company_name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B", validation_company_name: "Empresa B")
    @caio = create_member!(name: "Caio", email: "caio@duas-empresas.test", account: @account_a, role: "admin")
    create_member!(name: "Bia", email: "bia@empresa-b.test", account: @account_b, role: "admin")
    AccountMembership.create!(account: @account_b, user: @caio, role: "viewer")
    @lot_a = create_analytics_batch!(account: @account_a, user: @caio, started_at: 1.day.ago)
    @lot_b = create_analytics_batch!(account: @account_b, user: @caio, started_at: 1.day.ago)
    @outsider = Account.create!(name: "Empresa C")
    post user_session_url, params: { user: { email: @caio.email, password: TenancyTestHelpers::DEFAULT_PASSWORD } }
  end

  test "starts in the oldest membership and lists the other company" do
    get supplier_imports_url

    assert_includes response.body, @lot_a.display_code
    assert_not_includes response.body, @lot_b.display_code
    assert_select "form[action='#{account_selection_path}'] button", count: 2
  end

  test "switches company and applies the role of that membership" do
    post account_selection_url, params: { account_id: @account_b.id }
    assert_redirected_to root_url

    get supplier_imports_url
    assert_includes response.body, @lot_b.display_code
    assert_not_includes response.body, @lot_a.display_code

    get company_platform_settings_url
    assert_redirected_to root_url, "como viewer na Empresa B, não abre configurações"
  end

  test "cannot select a company without an active membership" do
    post account_selection_url, params: { account_id: @outsider.id }
    assert_response :not_found

    AccountMembership.find_by(account: @account_b, user: @caio).disable!
    post account_selection_url, params: { account_id: @account_b.id }
    assert_response :not_found

    get supplier_imports_url
    assert_includes response.body, @lot_a.display_code
  end
end
