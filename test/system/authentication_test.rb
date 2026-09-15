require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "opens the sign in page" do
    visit new_user_session_path

    assert_selector "h2", text: "Entrar"
    assert_field "E-mail corporativo"
    assert_button "Acessar painel"
  end
end
