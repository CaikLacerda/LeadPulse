require "test_helper"

module CommercialOpportunities
  class ExportXlsxServiceTest < ActiveSupport::TestCase
    test "exports a valid workbook with the commercial collection fields" do
      user = User.create!(
        name: "Operação Comercial",
        email: "commercial-xlsx@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      supplier_import = user.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD
      )
      opportunity = user.commercial_opportunities.create!(
        supplier_import: supplier_import,
        source_external_id: "supplier-xlsx-1",
        supplier_name: "Aços Campinas",
        callback_phone: "+5511987654321",
        callback_preferred_time: "Dia 26 de julho às cinco da tarde",
        callback_preferred_at: Time.zone.parse("2026-07-26 20:00:00 UTC"),
        status: CommercialOpportunity::STATUS_COMPLETED,
        result_ready: true,
        product_specification: "Chapa galvanizada 2 mm",
        unit_price: "R$ 120 por chapa",
        lot_price_ranges: "R$ 110 acima de 50 chapas",
        minimum_order: "10 chapas",
        normalized_product_specification: "Chapa galvanizada de 2 mm",
        normalized_unit_price: "R$ 120,00 por chapa",
        normalized_lot_price_ranges: "50 chapas: R$ 5.500,00 por lote",
        normalized_minimum_order: "10 chapas",
        normalization_source: "openai",
        outcome: "collected"
      )

      export = ExportXlsxService.new(commercial_opportunity: opportunity).call

      assert_equal "retorno-comercial-#{opportunity.display_number}.xlsx", export[:filename]
      assert_equal ExportXlsxService::CONTENT_TYPE, export[:content_type]
      assert_equal "PK", export[:content].byteslice(0, 2)

      Tempfile.create([ "leadpulse-commercial-export", ".xlsx" ]) do |file|
        file.binmode
        file.write(export[:content])
        file.flush

        workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
        sheet = workbook.sheet(0)

        assert_equal [ "Coleta comercial" ], workbook.sheets
        assert_equal "Data e horário normalizados", sheet.cell(1, 4)
        assert_equal "Produto ou especificação", sheet.cell(1, 5)
        assert_equal "Aços Campinas", sheet.cell(2, 1)
        assert_equal "+5511987654321", sheet.cell(2, 2)
        assert_equal "Dia 26 de julho às cinco da tarde", sheet.cell(2, 3)
        assert_equal "26/07/2026 às 17:00", sheet.cell(2, 4)
        assert_equal "Chapa galvanizada de 2 mm", sheet.cell(2, 5)
        assert_equal "R$ 120,00 por chapa", sheet.cell(2, 6)
        assert_equal "50 chapas: R$ 5.500,00 por lote", sheet.cell(2, 7)
        assert_equal "10 chapas", sheet.cell(2, 8)
        assert_equal "Produto - resposta original", sheet.cell(1, 10)
        assert_equal "R$ 120 por chapa", sheet.cell(2, 11)
      end
    end
  end
end
