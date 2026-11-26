require "test_helper"

class AnalyticsApiTokensControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B")
    @admin_a = create_member!(name: "Ana", email: "ana@bi-a.test", account: @account_a, role: "admin")
    @manager_a = create_member!(name: "Mário", email: "mario@bi-a.test", account: @account_a, role: "manager")
    @admin_b = create_member!(name: "Bruno", email: "bruno@bi-b.test", account: @account_b, role: "admin")
  end

  test "admin creates a token, sees the secret once and then only the prefix" do
    sign_in_as(@admin_a)

    post analytics_api_tokens_url, params: { analytics_api_token: { name: "Power BI Financeiro" } }
    token = @account_a.analytics_api_tokens.sole
    follow_redirect!
    secret = css_select("#created_bi_token").first["value"]
    assert_equal token, AnalyticsApiToken.authenticate(secret)
    assert_equal @admin_a, token.created_by
    assert_equal "analytics_bi_token_created", PrivacyAuditEvent.where(account: @account_a).last.action

    get analytics_api_tokens_url
    assert_select "#created_bi_token", count: 0
    assert_not_includes response.body, secret
    assert_includes response.body, token.token_prefix
  end

  test "admin revokes a token of the company" do
    token = create_token(@account_a)
    sign_in_as(@admin_a)

    delete analytics_api_token_url(token)

    assert token.reload.revoked_at.present?
    assert_equal @admin_a, token.revoked_by
    assert_equal "analytics_bi_token_revoked", PrivacyAuditEvent.where(account: @account_a).last.action
  end

  test "other roles cannot manage tokens" do
    token = create_token(@account_a)
    sign_in_as(@manager_a)

    get analytics_api_tokens_url
    assert_redirected_to root_url
    assert_no_difference -> { AnalyticsApiToken.count } do
      post analytics_api_tokens_url, params: { analytics_api_token: { name: "Meu token" } }
    end
    delete analytics_api_token_url(token)
    assert token.reload.active?
  end

  test "a token of another company is not found" do
    token = create_token(@account_a)
    sign_in_as(@admin_b)

    delete analytics_api_token_url(token)
    assert_response :not_found
    assert token.reload.active?

    get analytics_api_tokens_url
    assert_not_includes response.body, token.token_prefix
  end

  private

  def create_token(account)
    account.analytics_api_tokens.new(name: "Power BI").tap(&:generate_secret).tap(&:save!)
  end

  def sign_in_as(user)
    post user_session_url, params: { user: { email: user.email, password: PASSWORD } }
  end
end
