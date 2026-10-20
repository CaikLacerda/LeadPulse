require "test_helper"

class SupplierImportTest < ActiveSupport::TestCase
  test "destroy removes local suppliers and import versions" do
    user = create_member!(
      name: "LeadPulse Operação",
      email: "destroy-import@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    supplier_import = account_of(user).supplier_imports.create!(
      created_by: user,
      status: SupplierImport::LOCAL_STATUS_PENDING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD
    )
    supplier = supplier_import.suppliers.create!(
      name: "Contato",
      company_name: "Fornecedor"
    )
    version = supplier_import.supplier_import_versions.create!(event: "import")

    supplier_import.destroy!

    assert_not Supplier.exists?(supplier.id)
    assert_not SupplierImportVersion.exists?(version.id)
  end

  test "rejects inconsistent row counters" do
    supplier_import = accounts(:one).supplier_imports.new(
      created_by: users(:one),
      status: SupplierImport::LOCAL_STATUS_PENDING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 1
    )

    assert_not supplier_import.valid?
    assert_includes supplier_import.errors[:base],
      "A soma de linhas válidas e inválidas não pode exceder o total de linhas."
  end

  test "evidence expiry without offset from the API is read as UTC" do
    supplier_import = accounts(:one).supplier_imports.new(
      response_payload: { "privacy_notice" => { "evidence_expires_at" => "2027-04-01T01:21:47.828574" } }
    )

    assert_equal Time.utc(2027, 4, 1, 1, 21, 47.828574r), supplier_import.evidence_expires_at
  end

  test "evidence expiry with an explicit offset keeps it" do
    supplier_import = accounts(:one).supplier_imports.new(
      response_payload: { "privacy_notice" => { "evidence_expires_at" => "2027-04-01T01:21:47-03:00" } }
    )

    assert_equal Time.utc(2027, 4, 1, 4, 21, 47), supplier_import.evidence_expires_at
  end
end
