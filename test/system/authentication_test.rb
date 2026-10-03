require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "opens the sign in page" do
    visit new_user_session_path

    assert_selector "h1", text: "Entrar"
    assert_field "E-mail corporativo"
    assert_field "Senha"
    assert_button "Entrar"
    assert_link "Esqueceu a senha?"
  end

  test "shows the backend errors next to each sign up field" do
    visit new_user_registration_path
    fill_in "E-mail corporativo", with: "nova.pessoa@example.com"
    fill_in "Senha", with: "123"
    fill_in "Confirmar senha", with: "456"
    click_button "Criar conta"

    assert_selector "#user_name[aria-invalid='true'][aria-describedby='user_name_error']"
    assert_selector "#user_name_error", text: "Nome não pode ficar em branco"
    assert_selector "#user_password[aria-describedby='password_hint user_password_error']"
    assert_selector "#user_password_error", text: "Senha precisa ter pelo menos 6 caracteres"
    assert_selector "#user_password_confirmation_error", text: "Confirmação da senha não confere com Senha"
    assert_selector ".auth-errors[role='alert']", text: "Revise os campos abaixo."
  end

  test "signs up and signs in through the redesigned forms" do
    visit new_user_registration_path
    fill_in "Nome completo", with: "Nova Pessoa"
    fill_in "E-mail corporativo", with: "nova.pessoa@example.com"
    fill_in "Senha", with: "senha-segura-1"
    fill_in "Confirmar senha", with: "senha-segura-1"
    click_button "Criar conta"

    assert_no_selector "h1", text: "Criar conta"
    assert User.exists?(email: "nova.pessoa@example.com")

    Capybara.reset_sessions!
    visit new_user_session_path
    fill_in "E-mail corporativo", with: "nova.pessoa@example.com"
    fill_in "Senha", with: "senha-segura-1"
    check "Manter conectado neste dispositivo"
    click_button "Entrar"

    assert_no_selector "h1", text: "Entrar"
  end

  test "requests a password reset" do
    visit new_user_session_path
    click_link "Esqueceu a senha?"
    assert_selector "h1", text: "Recuperar acesso"
    fill_in "E-mail corporativo", with: users(:one).email
    click_button "Enviar link de redefinição"

    assert_text "instruções para redefinir sua senha"
  end
end
