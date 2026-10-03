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

  test "public homepage has the sections, SEO tags and real product screens" do
    get root_url

    assert_select "title", text: /LeadPulse/
    assert_select "meta[name='description'][content]", count: 1
    assert_select "meta[property='og:image'][content*='og-leadpulse']", count: 1
    assert_select "h1", count: 1
    %w[inicio como-funciona recursos planos sobre contato].each do |anchor|
      assert_select "section##{anchor}", count: 1
    end
    assert_select "header.site-header nav[aria-label='Navegação principal'] a", count: 5
    assert_select "header.site-header a[href='#{new_user_session_path}']", text: "Entrar"
    assert_select "footer.site-footer a[href='#{terms_path}']"
    assert_select "footer.site-footer a[href='#{privacy_path}']"
    # Telas reais servidas pelo próprio app (CSP), com dimensões para evitar layout shift.
    assert_select ".landing-shot img[src*='/assets/landing/produto-'][width][height][alt]", count: 4
    assert_select "img[src^='http']", count: 0
    assert_select "main main", count: 0
    assert_no_match(/R\$|por mês|\/mês/, @response.body)
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
    user = create_member!(
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
    user = create_member!(name: "Tema", email: email, password: password, password_confirmation: password)
    post user_session_url, params: { user: { email: user.email, password: password } }
  end
end
