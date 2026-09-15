require "test_helper"

class SupplierImportTest < ActiveSupport::TestCase
  test "destroy removes local suppliers and import versions" do
    user = User.create!(
      name: "LeadPulse Operação",
      email: "destroy-import@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    supplier_import = user.supplier_imports.create!(
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
    supplier_import = users(:one).supplier_imports.new(
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
end
