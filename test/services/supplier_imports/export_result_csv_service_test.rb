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
      assert_equal "Fornecedor qualificado", row["Resultado"]
      assert_equal "Ligação", row["Confirmação por"]
      assert_equal "04/04/2026 11:45", row["Finalizado em"]
    end

    test "exports supplier rejection matching company yes and segment no" do
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
              "observation" => "Ligacao confirmou que a empresa nao fornece o segmento informado.",
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

      assert_equal "Sim", row["Telefone pertence à empresa"]
      assert_equal "Não", row["Fornece o segmento"]
      assert_equal "", row["Aceita retorno comercial"]
      assert_equal "Não fornece o segmento", row["Resultado"]
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
