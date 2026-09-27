require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "renders public homepage" do
    get root_url

    assert_response :success
    assert_select "h1", text: /Venda para empresas que já fazem sentido/
    assert_select "*", text: /encontra contatos dentro do seu recorte/
    assert_select "a", text: "Criar conta"
    assert_no_match(/\+2\.000 empresas|100 validações gratuitas/, @response.body)
  end

  test "renders public terms and privacy pages" do
    get terms_url
    assert_response :success
    assert_select "h1", text: "Termos de Serviço"

    get privacy_url
    assert_response :success
    assert_select "h1", text: "Política de Privacidade"
  end


  test "viewer dashboard does not offer administrative actions" do
    password = "Password123!"
    user = User.create!(
      name: "Leitor",
      email: "viewer-home@example.com",
      password: password,
      password_confirmation: password,
      role: "viewer"
    )
    post user_session_url, params: { user: { email: user.email, password: password } }

    get root_url

    assert_response :success
    assert_select "a", text: "Configurações", count: 0
    assert_select "a", text: "Novo lote", count: 0
    assert_select "a", text: "Nova busca", count: 0
    assert_select "nav[aria-label='Navegação principal']", count: 1
    assert_select "aside#app-sidebar", count: 1
    assert_select "aside#app-sidebar a", text: "Configurações", count: 0
    assert_select "aside#app-sidebar a", text: "Lotes de validação", count: 1
    assert_select ".app-account-avatar", count: 1
  end

  test "workspace follows the saved theme preference" do
    sign_in_as_new_user("theme-dark@example.com")
    cookies[:lp_theme] = "dark"

    get root_url

    assert_select "html[data-theme='dark']", count: 1
    assert_select "body[data-page-theme='dark']", count: 1
    assert_select ".app-theme-switch__option[data-appearance-theme-param='dark'][aria-pressed='true']", count: 1
  end

  test "system theme leaves the choice to the operating system" do
    sign_in_as_new_user("theme-system@example.com")
    cookies[:lp_theme] = "qualquer-coisa"

    get root_url

    assert_select "html[data-theme]", count: 0
    assert_select ".app-theme-switch__option[data-appearance-theme-param='system'][aria-pressed='true']", count: 1
  end

  test "public pages always render in the light theme" do
    cookies[:lp_theme] = "dark"

    get root_url

    assert_select "html[data-theme='light']", count: 1
  end

  private

  def sign_in_as_new_user(email)
    password = "Password123!"
    user = User.create!(name: "Tema", email: email, password: password, password_confirmation: password)
    post user_session_url, params: { user: { email: user.email, password: password } }
  end
end
