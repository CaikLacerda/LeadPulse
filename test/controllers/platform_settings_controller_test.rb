require "test_helper"

class PlatformSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = create_member!(
      name: "Usuário de leitura",
      email: "viewer-settings@example.com",
      password: @password,
      password_confirmation: @password,
      role: "viewer"
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }
  end

  test "viewer cannot open provider settings" do
    get twilio_platform_settings_url

    assert_redirected_to root_url
    assert_equal "Seu perfil não possui permissão para alterar configurações.", flash[:alert]
  end

  test "viewer cannot change company settings by direct request" do
    patch company_platform_settings_url, params: {
      user: {
        validation_company_name: "Empresa alterada",
        validation_spoken_company_name: "Empresa alterada",
        validation_owner_name: "Outro responsável",
        validation_owner_email: "outro@example.com"
      }
    }

    assert_redirected_to root_url
    assert_nil @user.reload.validation_company_name
  end


  test "administrator can render every settings section in Portuguese" do
    membership_of(@user).update!(role: "admin")

    [
      company_platform_settings_url,
      twilio_platform_settings_url,
      openai_platform_settings_url,
      api_token_platform_settings_url,
      lgpd_platform_settings_url
    ].each do |url|
      get url

      assert_response :success
      assert_no_match(/translation_missing/, @response.body)
    end
  end

  test "administrator sees the institutional information field on company settings" do
    membership_of(@user).update!(role: "admin")

    get company_platform_settings_url

    assert_response :success
    assert_select "textarea[name='account[validation_calling_profile]'][maxlength='1500']"
    assert_match "Informações institucionais para a ligação", @response.body
  end
end
