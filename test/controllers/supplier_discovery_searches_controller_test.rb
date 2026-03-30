require "test_helper"

class SupplierDiscoverySearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "LeadPulse Test",
      email: "busca@example.com",
      password: @password,
      password_confirmation: @password
    )
  end

  test "redirects guests to sign in" do
    get supplier_discovery_searches_url

    assert_redirected_to new_user_session_path
  end

  test "renders search index for signed users" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_discovery_searches_url

    assert_response :success
    assert_select "h1", text: /Busca de fornecedores/
    assert_select "button", text: /Nova busca/
  end
end
