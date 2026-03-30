require "test_helper"

class ValidationAuditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "Caio Alves",
      email: "auditoria@example.com",
      password: @password,
      password_confirmation: @password
    )

    @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      response_payload: {
        "records" => [
          {
            "external_id" => "1",
            "client_name" => "Fornecedor Exemplo",
            "call_attempts" => [
              {
                "attempt_number" => 1,
                "provider_call_id" => "CA123",
                "result" => "inconclusive",
                "started_at" => "2026-04-03T10:00:00Z",
                "finished_at" => "2026-04-03T10:05:00Z",
                "customer_transcript" => "Pode falar.",
                "assistant_transcript" => "Estamos validando o segmento.",
                "transcript_summary" => "Cliente confirmou continuidade."
              }
            ]
          }
        ]
      }
    )
  end

  test "redirects guests to sign in" do
    get validation_audits_url

    assert_redirected_to new_user_session_path
  end

  test "renders audit index for signed users" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get validation_audits_url

    assert_response :success
    assert_select "h1", text: /Auditoria/
    assert_select "*", text: /Fornecedor Exemplo/
    assert_select "*", text: /Pode falar/
    assert_select "*", text: /Estamos validando o segmento/
  end
end
