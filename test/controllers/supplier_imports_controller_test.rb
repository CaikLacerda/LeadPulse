require "test_helper"
require "tempfile"

class SupplierImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "LeadPulse Validação",
      email: "dados@example.com",
      password: @password,
      password_confirmation: @password
    )
  end

  test "redirects guests to sign in" do
    get supplier_imports_url

    assert_redirected_to new_user_session_path
  end

  test "renders index for signed users" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_imports_url

    assert_response :success
    assert_select "h1", text: /Validação/
    assert_select "button", text: /Novo lote/
    assert_no_match(/translation_missing/, @response.body)
  end

  test "renders import detail for signed users" do
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      response_payload: {
        "records" => [
          {
            "external_id" => "1",
            "client_name" => "Alfa Comercio",
            "phone_original" => "19999999999",
            "business_status" => "confirmed_by_call"
          }
        ]
      }
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_import_url(supplier_import)

    assert_response :success
    assert_select "h1", text: supplier_import.display_code
    assert_select "*", text: /Alfa Comercio/
  end

  test "legacy import route redirects to index with modal open" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get import_supplier_imports_url

    assert_redirected_to supplier_imports_url(open_import_modal: "1")
  end

  test "returns preview json for signed users" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    tempfile = Tempfile.new([ "preview", ".csv" ])
    tempfile.write("empresa,cnpj,telefone\nAlfa Comercio,12.345.678/0001-95,19999999999\n")
    tempfile.rewind

    upload = Rack::Test::UploadedFile.new(tempfile.path, "text/csv", original_filename: "preview.csv")

    post preview_import_supplier_imports_url, params: {
      file: upload,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      separator: ","
    }

    assert_response :success

    payload = JSON.parse(@response.body)
    assert_equal true, payload["success"]
    assert_equal 1, payload.dig("preview", "valid_rows")
    assert_equal true, payload.dig("preview", "import_allowed")
  ensure
    tempfile.close!
  end

  test "imports using account lgpd defaults without modal acknowledgement" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    tempfile = Tempfile.new([ "import", ".csv" ])
    tempfile.write("empresa,cnpj,telefone\nAlfa Comercio,12.345.678/0001-95,19999999999\n")
    tempfile.rewind

    upload = Rack::Test::UploadedFile.new(tempfile.path, "text/csv", original_filename: "import.csv")

    assert_difference -> { @user.supplier_imports.count }, 1 do
      post create_import_supplier_imports_url, params: {
        file: upload,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        separator: ","
      }
    end

    assert_redirected_to supplier_imports_url
    assert_equal @user.lgpd_legal_basis, @user.supplier_imports.last.request_payload.dig("privacy_notice", "legal_basis")
  ensure
    tempfile.close!
  end

  test "sync status requires a started remote batch" do
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PENDING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    post sync_status_supplier_import_url(supplier_import)

    assert_redirected_to supplier_imports_url
    assert_equal I18n.t("supplier_imports.messages.not_started_yet"), flash[:alert]
  end

  test "sync status reports missing api token" do
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PROCESSING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      remote_batch_id: "remote-batch-without-token",
      remote_batch_status: "processing",
      validation_started_at: 5.minutes.ago
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    post sync_status_supplier_import_url(supplier_import)

    assert_redirected_to supplier_imports_url
    assert_equal "Gere o token da API antes de consultar o status do lote.", flash[:alert]
  end

  test "sync status updates the local import from the validation api" do
    @user.update!(validation_api_token: "lp_test_token")
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PROCESSING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      remote_batch_id: "remote-batch-001",
      remote_batch_status: "processing",
      validation_started_at: 5.minutes.ago
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    fake_response = {
      "batch_id" => "remote-batch-001",
      "batch_status" => "completed",
      "result_ready" => true,
      "finished_at" => Time.current.iso8601,
      "total_records" => 1,
      "summary" => {
        "validated_records" => 1,
        "failed_records" => 0,
        "invalid_phone" => 0,
        "confirmed_by_call" => 1,
        "confirmed_by_whatsapp" => 0,
        "confirmed_by_email" => 0
      },
      "records" => [
        {
          "external_id" => "1",
          "client_name" => "Alfa Comercio",
          "final_status" => "validated",
          "business_status" => "confirmed_by_call"
        }
      ]
    }
    fake_remote_service = Struct.new(:response) do
      def call(api_token:, batch_id:)
        raise "unexpected api token" unless api_token == "lp_test_token"
        raise "unexpected batch id" unless batch_id == "remote-batch-001"

        response
      end
    end.new(fake_response)

    service_class = ValidationApi::Validations::ShowBatchService
    original_constructor = service_class.method(:new)
    service_class.define_singleton_method(:new) { fake_remote_service }

    begin
      post sync_status_supplier_import_url(supplier_import)
    ensure
      service_class.define_singleton_method(:new, original_constructor)
    end

    assert_redirected_to supplier_imports_url
    assert_equal I18n.t("supplier_imports.messages.synced_success"), flash[:notice]

    supplier_import.reload
    assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
    assert_equal "completed", supplier_import.remote_batch_status
    assert_equal true, supplier_import.result_ready
    assert_equal fake_response, supplier_import.response_payload
    assert supplier_import.last_synced_at.present?
    assert_nil supplier_import.error_message
  end

  test "json sync reports terminal state for automatic page reconciliation" do
    @user.update!(validation_api_token: "lp_test_token")
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PROCESSING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      remote_batch_id: "remote-json-sync",
      remote_batch_status: "processing",
      validation_started_at: 5.minutes.ago
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    fake_service = Object.new
    fake_service.define_singleton_method(:call) do
      supplier_import.update!(
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        remote_batch_status: "completed",
        result_ready: true
      )
    end
    service_class = SupplierImports::SyncRemoteStatusService
    original_constructor = service_class.method(:new)
    service_class.define_singleton_method(:new) { |**| fake_service }

    begin
      post sync_status_supplier_import_url(supplier_import, format: :json)
    ensure
      service_class.define_singleton_method(:new, original_constructor)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, payload["status"]
    assert_equal true, payload["changed"]
    assert_equal true, payload["terminal"]
  end

  test "viewer cannot delete a lot" do
    @user.update!(role: "viewer")
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PENDING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    delete supplier_import_url(supplier_import)

    assert_redirected_to supplier_imports_url
    assert_equal "Seu perfil não possui permissão para excluir lotes.", flash[:alert]
    assert SupplierImport.exists?(supplier_import.id)
  end

  test "viewer cannot open evidence or synchronize a lot by direct url" do
    @user.update!(role: "viewer")
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_PROCESSING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      remote_batch_id: "protected-batch",
      validation_started_at: 5.minutes.ago,
      response_payload: { "records" => [ { "client_name" => "Empresa protegida" } ] }
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_import_url(supplier_import)
    assert_redirected_to supplier_imports_url
    assert_equal "Seu perfil não possui permissão para visualizar evidências.", flash[:alert]

    post sync_status_supplier_import_url(supplier_import)
    assert_redirected_to supplier_imports_url
    assert_equal "Seu perfil não possui permissão para consultar o status da validação.", flash[:alert]
  end
end
