require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "renders public homepage" do
    get root_url

    assert_response :success
    assert_select "h1", text: /Abra o mercado certo/
    assert_select "*", text: /Abra o mercado certo e valide os contatos/
    assert_select "a", text: "Criar conta"
  end
end
