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

    tempfile = Tempfile.new(["preview", ".csv"])
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

    tempfile = Tempfile.new(["import", ".csv"])
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
end
