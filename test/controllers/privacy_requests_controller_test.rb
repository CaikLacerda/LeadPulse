require "test_helper"

class PrivacyRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "Responsável LGPD",
      email: "privacy-admin@example.com",
      password: @password,
      password_confirmation: @password,
      role: "admin"
    )
    @supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      response_payload: {
        "records" => [ { "external_id" => "1", "customer_transcript" => "Dado pessoal" } ]
      }
    )
  end

  test "requires authentication and an LGPD manager" do
    get privacy_requests_url
    assert_redirected_to new_user_session_path

    @user.update!(role: "viewer")
    sign_in_user
    get privacy_requests_url

    assert_redirected_to root_path
    assert_equal "Seu perfil não possui permissão para gerenciar LGPD.", flash[:alert]
  end

  test "creates a request linked to a batch from the same account" do
    sign_in_user

    assert_difference -> { PrivacyRequest.count }, 1 do
      post privacy_requests_url, params: {
        privacy_request: valid_request_params.merge(supplier_import_id: @supplier_import.id)
      }
    end

    request = PrivacyRequest.order(:id).last
    assert_equal @user, request.user
    assert_equal @supplier_import, request.supplier_import
    assert_redirected_to privacy_requests_path
  end

  test "does not allow linking another account batch" do
    other_user = User.create!(
      name: "Outra empresa",
      email: "privacy-other@example.com",
      password: @password,
      password_confirmation: @password
    )
    other_import = other_user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD
    )
    sign_in_user

    assert_no_difference -> { PrivacyRequest.count } do
      post privacy_requests_url, params: {
        privacy_request: valid_request_params.merge(supplier_import_id: other_import.id)
      }
    end

    assert_response :not_found
  end

  test "resolving anonymization removes local evidence and records completion" do
    privacy_request = @user.privacy_requests.create!(
      supplier_import: @supplier_import,
      request_type: "anonymization",
      subject_name: "Titular",
      subject_contact: "titular@example.com"
    )
    sign_in_user

    patch privacy_request_url(privacy_request), params: {
      privacy_request: { status: "resolved", resolution: "Atendida após verificação." }
    }

    assert_redirected_to privacy_requests_path
    assert_equal "resolved", privacy_request.reload.status
    assert privacy_request.resolved_at.present?
    assert_nil @supplier_import.reload.response_payload.dig("records", 0, "customer_transcript")
  end

  private

  def sign_in_user
    post user_session_url, params: {
      user: { email: @user.email, password: @password }
    }
  end

  def valid_request_params
    {
      request_type: "access",
      subject_name: "Titular",
      subject_contact: "titular@example.com",
      description: "Solicitação recebida pelo canal de privacidade."
    }
  end
end
