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
      assert_equal [ "Telefone não informado" ], result.preview[:invalid_rows_preview].first[:errors]
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
      assert_includes result.preview[:warnings], "Para lote de segmento, a planilha precisa informar o segmento."
    end

    test "marks duplicated phones as invalid rows" do
      file = Struct.new(:original_filename, :read).new(
        "duplicados.csv",
        <<~CSV
          empresa,cnpj,telefone
          Alfa Comercio,12.345.678/0001-95,5519999999999
          Alfa Filial,12.345.678/0002-76,19999999999
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL).call

      assert result.success?
      assert_equal 2, result.preview[:total_rows]
      assert_equal 1, result.preview[:valid_rows]
      assert_equal 1, result.preview[:invalid_rows]
      assert_match(/Telefone duplicado/, result.preview[:invalid_rows_preview].first[:errors].join(" "))
    end

    test "allows supplier preview with segment and no predefined callback" do
      file = Struct.new(:original_filename, :read).new(
        "segmento.csv",
        <<~CSV
          Nome do fornecedor,Telefone,Segmento
          Terra Vegetal,19999999999,Adubo
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER).call

      assert result.success?
      assert result.preview[:import_allowed]
      assert_equal "Terra Vegetal", result.preview[:sample_rows].first[:cells][1][:value]
      assert_not_includes result.preview[:columns], "Telefone de retorno"
    end

    test "translates supplier discovery technical columns" do
      file = Struct.new(:original_filename, :read).new(
        "fornecedores.csv",
        <<~CSV
          Search,Segmento,Region,Empresa,Telefone,Website,Address,Google maps url,Google place,Openstreetmap url,Osm place,Location provider,Location precision,Source urls,Discovery confidence
          BS-001,Adubo,Rondônia,Boa Safra,69999999999,https://example.com,Rua A,https://maps.google.com/example,place-1,https://openstreetmap.org/example,node-1,openstreetmap,estabelecimento,https://source.example,alta
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER).call

      assert result.success?
      assert_includes result.preview[:columns], "Código da busca"
      assert_includes result.preview[:columns], "Região"
      assert_includes result.preview[:columns], "Endereço"
      assert_includes result.preview[:columns], "Link do Google Maps"
      assert_includes result.preview[:columns], "ID do Google Places"
      assert_includes result.preview[:columns], "Link do OpenStreetMap"
      assert_includes result.preview[:columns], "Fonte da localização"
      assert_includes result.preview[:columns], "Precisão da localização"
      assert_includes result.preview[:columns], "Fontes consultadas"
      assert_includes result.preview[:columns], "Confiança da busca"
    end

    test "ignores rows that only contain non importable technical data or notes" do
      file = Struct.new(:original_filename, :read).new(
        "fornecedores.csv",
        <<~CSV
          Empresa,Telefone,Segmento,Address,Source urls,Observação
          Boa Safra,69999999999,Adubo,Rua A,https://source.example,Fornecedor válido
          ,,,Rua residual,https://residual.example,
          ,,,,,Texto residual sem fornecedor
        CSV
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER).call

      assert result.success?
      assert_equal 1, result.preview[:total_rows]
      assert_equal 1, result.preview[:valid_rows]
      assert_equal 0, result.preview[:invalid_rows]
    end

    test "rejects files above the batch row limit" do
      rows = (1..1_001).map { |index| "Empresa #{index},12.345.678/0001-95,19999999999" }
      file = Struct.new(:original_filename, :read).new(
        "grande.csv",
        ([ "empresa,cnpj,telefone" ] + rows).join("\n")
      )

      result = PreviewUploadService.new(file: file, workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL).call

      refute result.success?
      assert_equal "A planilha excede o limite de 1000 registros por lote.", result.error_message
    end

    test "returns a readable error for malformed csv" do
      file = Struct.new(:original_filename, :read).new(
        "invalido.csv",
        "empresa,cnpj,telefone\n\"Empresa sem fechamento,123,19999999999"
      )

      result = PreviewUploadService.new(file: file).call

      refute result.success?
      assert_match(/CSV inválido/, result.error_message)
    end
  end
end
