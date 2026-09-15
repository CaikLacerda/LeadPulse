require "test_helper"
require "csv"

module SupplierImports
  class ExportResultCsvServiceTest < ActiveSupport::TestCase
    test "exports curated cadastral columns" do
      supplier_import = SupplierImport.create!(
        user: build_user("cadastral-export@example.com"),
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
              "client_name" => "Alfa Comercio Industrial LTDA",
              "cnpj_original" => "12.345.678/0001-95",
              "phone_original" => "19994110571",
              "validated_phone" => "5519994110571",
              "phone_type" => "mobile",
              "business_status" => "confirmed_by_call",
              "call_status" => "answered",
              "confirmation_source" => "voice_call",
              "phone_confirmed" => true,
              "observation" => "Ligação confirmada por resposta positiva do atendente.",
              "call_attempts" => [
                { "finished_at" => "2026-04-04T14:33:11.648146" }
              ]
            }
          ]
        }
      )

      export = ExportResultCsvService.new(supplier_import: supplier_import).call
      csv = CSV.parse(export[:content], headers: true)

      assert_equal [
        "Registro",
        "Empresa",
        "CNPJ",
        "Telefone informado",
        "Telefone validado",
        "Tipo de telefone",
        "Resultado",
        "Status da ligação",
        "Confirmação por",
        "Telefone confirmado",
        "Observação",
        "Finalizado em"
      ], csv.headers

      row = csv.first
      assert_equal "Alfa Comercio Industrial LTDA", row["Empresa"]
      assert_equal "Confirmada", row["Resultado"]
      assert_equal "Atendida", row["Status da ligação"]
      assert_equal "Ligação", row["Confirmação por"]
      assert_equal "Sim", row["Telefone confirmado"]
      assert_equal "Celular", row["Tipo de telefone"]
      assert_equal "04/04/2026 11:33", row["Finalizado em"]
    end

    test "exports curated supplier columns" do
      supplier_import = SupplierImport.create!(
        user: build_user("supplier-export@example.com"),
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        response_payload: {
          "records" => [
            {
              "external_id" => "7",
              "client_name" => "Fornecedor Agro LTDA",
              "phone_original" => "19988887777",
              "validated_phone" => "5519988887777",
              "phone_type" => "mobile",
              "call_status" => "answered",
              "confirmation_source" => "voice_call",
              "final_status" => "qualified_supplier",
              "observation" => "Fornecedor confirmou segmento e abertura comercial.",
              "supplier_validation" => {
                "segment_name" => "Adubo",
                "phone_belongs_to_company" => true,
                "supplies_segment" => true,
                "commercial_interest" => true,
                "callback_phone_informed" => "+5519988887777",
                "callback_preferred_time" => "Dia 26 de julho às cinco da tarde",
                "callback_preferred_at" => "2026-07-26T20:00:00+00:00",
                "outcome" => "qualified_supplier"
              },
              "call_attempts" => [
                { "finished_at" => "2026-04-04T14:45:00" }
              ]
            }
          ]
        }
      )

      export = ExportResultCsvService.new(supplier_import: supplier_import).call
      csv = CSV.parse(export[:content], headers: true)

      assert_equal [
        "Registro",
        "Empresa",
        "Segmento",
        "Telefone informado",
        "Telefone validado",
        "Tipo de telefone",
        "Telefone pertence à empresa",
        "Fornece o segmento",
        "Aceita retorno comercial",
        "Telefone escolhido para retorno",
        "Preferência de retorno informada",
        "Data e horário normalizados",
        "Resultado",
        "Status da ligação",
        "Confirmação por",
        "Observação",
        "Finalizado em"
      ], csv.headers

      row = csv.first
      assert_equal "Fornecedor Agro LTDA", row["Empresa"]
      assert_equal "Adubo", row["Segmento"]
      assert_equal "Sim", row["Telefone pertence à empresa"]
      assert_equal "Sim", row["Fornece o segmento"]
      assert_equal "Sim", row["Aceita retorno comercial"]
      assert_equal "+5519988887777", row["Telefone escolhido para retorno"]
      assert_equal "Dia 26 de julho às cinco da tarde", row["Preferência de retorno informada"]
      assert_equal "26/07/2026 17:00", row["Data e horário normalizados"]
      assert_equal "Fornecedor qualificado", row["Resultado"]
      assert_equal "Ligação", row["Confirmação por"]
      assert_equal "04/04/2026 11:45", row["Finalizado em"]
    end

    test "neutralizes spreadsheet formulas in exported text" do
      supplier_import = SupplierImport.create!(
        user: build_user("csv-formula-protection@example.com"),
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
              "client_name" => "=HYPERLINK(\"https://example.invalid\")",
              "phone_original" => "19999999999",
              "business_status" => "validation_failed"
            }
          ]
        }
      )

      export = ExportResultCsvService.new(supplier_import: supplier_import).call
      row = CSV.parse(export[:content], headers: true).first

      assert_equal "'=HYPERLINK(\"https://example.invalid\")", row["Empresa"]
      assert_equal "+5519999999999", Spreadsheets::CellSanitizer.sanitize("+5519999999999")
    end

    test "does not classify an ambiguous observation by matching a phrase" do
      supplier_import = SupplierImport.create!(
        user: build_user("supplier-export-negative@example.com"),
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        segment_name: "Adubo",
        response_payload: {
          "records" => [
            {
              "external_id" => "8",
              "client_name" => "Terra Vegetal e Adubo",
              "phone_original" => "19988887777",
              "validated_phone" => "5519988887777",
              "phone_type" => "mobile",
              "call_status" => "answered",
              "call_result" => "rejected",
              "confirmation_source" => "voice_call",
              "observation" => "Não sei dizer se a empresa não fornece o segmento ou se devo consultar outra pessoa.",
              "supplier_validation" => {
                "segment_name" => "Adubo"
              },
              "call_attempts" => [
                { "finished_at" => "2026-04-04T21:04:12" }
              ]
            }
          ]
        }
      )

      export = ExportResultCsvService.new(supplier_import: supplier_import).call
      csv = CSV.parse(export[:content], headers: true)
      row = csv.first

      assert_equal "", row["Telefone pertence à empresa"]
      assert_equal "", row["Fornece o segmento"]
      assert_equal "", row["Aceita retorno comercial"]
      assert_equal "Rejeitada", row["Resultado"]
    end

    test "exports the latest human review without overwriting the automatic evidence" do
      user = build_user("supplier-reviewed-export@example.com")
      automatic_payload = {
        "records" => [
          {
            "external_id" => "reviewed-1",
            "client_name" => "Fornecedor Revisado",
            "supplier_validation" => {
              "phone_belongs_to_company" => true,
              "supplies_segment" => true,
              "commercial_interest" => true,
              "outcome" => "qualified_supplier"
            }
          }
        ]
      }
      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        response_payload: automatic_payload
      )
      supplier_import.audit_reviews.create!(
        user: user,
        record_external_id: "reviewed-1",
        original_result: "qualified_supplier",
        reviewed_result: "not_interested",
        reviewed_at: Time.current
      )

      row = CSV.parse(
        ExportResultCsvService.new(supplier_import: supplier_import).call[:content],
        headers: true
      ).first

      assert_equal "Sem interesse comercial", row["Resultado"]
      assert_equal "Sim", row["Telefone pertence à empresa"]
      assert_equal "Sim", row["Fornece o segmento"]
      assert_equal "Não", row["Aceita retorno comercial"]
      assert_equal automatic_payload, supplier_import.reload.response_payload
    end

    test "exports result xlsx with spreadsheet content type" do
      supplier_import = SupplierImport.create!(
        user: build_user("xlsx-export@example.com"),
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
              "phone_original" => "19994110571",
              "validated_phone" => "5519994110571",
              "business_status" => "confirmed_by_call"
            }
          ]
        }
      )

      export = ExportResultXlsxService.new(supplier_import: supplier_import).call

      assert_equal "lote-#{supplier_import.display_number}-resultado.xlsx", export[:filename]
      assert_equal ExportResultXlsxService::CONTENT_TYPE, export[:content_type]
      assert_equal "PK", export[:content].byteslice(0, 2)

      Tempfile.create([ "leadpulse-export", ".xlsx" ]) do |file|
        file.binmode
        file.write(export[:content])
        file.flush

        workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
        sheet = workbook.sheet(0)
        assert_equal [ "Resultado" ], workbook.sheets
        assert_equal "Registro", sheet.cell(1, 1)
        assert_equal "Alfa Comercio", sheet.cell(2, 2)
        assert_equal "5519994110571", sheet.cell(2, 5)
      end
    end

    private

    def build_user(email)
      User.create!(
        name: "LeadPulse Operacao",
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      )
    end
  end
end
