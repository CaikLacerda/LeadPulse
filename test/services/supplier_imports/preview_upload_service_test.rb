require "test_helper"

module SupplierImports
  class PreviewUploadServiceTest < ActiveSupport::TestCase
    test "builds preview summary for cadastral csv" do
      file = Struct.new(:original_filename, :read).new(
        "clientes.csv",
        <<~CSV
          empresa,cnpj,telefone
          Alfa Comercio,12.345.678/0001-95,19999999999
          Beta Sem Telefone,23.456.789/0001-95,
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL).call

      assert result.success?
      assert_equal 2, result.preview[:total_rows]
      assert_equal 1, result.preview[:valid_rows]
      assert_equal 1, result.preview[:invalid_rows]
      assert_equal true, result.preview[:import_allowed]
      assert_includes result.preview[:columns], "Empresa"
      assert_includes result.preview[:columns], "CNPJ"
      assert_includes result.preview[:columns], "Telefone"
      assert_equal "Alfa Comercio", result.preview[:sample_rows].first[:cells][1][:value]
    end

    test "blocks supplier preview when file does not include required metadata" do
      file = Struct.new(:original_filename, :read).new(
        "segmento.csv",
        <<~CSV
          empresa,telefone
          Terra Vegetal,19999999999
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER).call

      assert result.success?
      assert_equal false, result.preview[:import_allowed]
      assert_includes result.preview[:warnings], "Para lote de segmento, a planilha precisa trazer segmento e telefone de retorno."
    end
  end
end
