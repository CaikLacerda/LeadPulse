require "test_helper"

class AuthLayoutTest < ActionDispatch::IntegrationTest
  test "sign in uses the landing look without the workspace stylesheet" do
    get new_user_session_path

    assert_response :success
    assert_select ".auth-card .auth-panel h1", text: "Entrar"
    assert_select ".auth-logo img[src*='/assets/landing/brand-lockup'][alt]", count: 1
    assert_select "a.auth-switch[href='#{new_user_registration_path}']", text: "Criar conta"
    assert_select ".auth-showcase .brand-object[data-controller='brand-object'][aria-hidden='true']", count: 1
    assert_select ".brand-object img[src*='/assets/brand/logo-symbol'][alt='']", count: 2
    assert_select ".auth-steps", count: 0
    assert_select "link[rel='stylesheet'][href*='/assets/landing/landing-']", count: 1
    assert_select "link[rel='stylesheet'][href*='/assets/landing/auth-']", count: 1
    assert_select "link[rel='stylesheet'][href*='/assets/tailwind']", count: 0
    assert_select "script[src*='/assets/landing/glow-']", count: 1
    assert_select ".auth-brand", count: 0
  end

  test "sign up shows the first steps and re-renders errors in the same layout" do
    get new_user_registration_path

    assert_select ".auth-card .auth-panel h1", text: "Criar conta"
    assert_select "a.auth-switch[href='#{new_user_session_path}']", text: "Entrar"
    assert_select ".auth-steps li", count: 3

    post user_registration_path, params: { user: { name: "", email: "nova@example.com", password: "123", password_confirmation: "456" } }

    assert_response :unprocessable_entity
    assert_select ".auth-card .auth-errors[role='alert']", text: /Revise os campos abaixo/
    assert_select "#user_name[aria-invalid='true']"
  end

  test "password recovery and invitations use the same sign-in look" do
    get new_user_password_path

    assert_response :success
    assert_select ".auth-card .auth-panel h1", text: "Recuperar acesso"
    assert_select "a.auth-switch[href='#{new_user_session_path}']", text: "Entrar"
    assert_select "link[rel='stylesheet'][href*='/assets/landing/auth-']", count: 1

    get invitation_path("token-que-nao-existe")

    assert_response :success
    assert_select ".auth-card .auth-panel h1", text: "Convite inválido"
  end
end
