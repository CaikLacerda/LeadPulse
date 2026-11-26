require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = create_member!(
      name: "Usuário de notificações",
      email: "notifications@example.com",
      password: @password,
      password_confirmation: @password
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }
  end

  test "marks visible notification keys as read only once" do
    notification_key = "pending_imports:2"

    post mark_notifications_read_url,
      params: { notification_keys: [ notification_key ] },
      as: :json

    assert_response :no_content
    assert_equal [ notification_key ], @user.workspace_notification_reads.pluck(:notification_key)

    post mark_notifications_read_url,
      params: { notification_keys: [ notification_key ] },
      as: :json

    assert_response :no_content
    assert_equal 1, @user.workspace_notification_reads.count
  end
end
