require "test_helper"

module SupplierImports
  class AuditEntriesServiceTest < ActiveSupport::TestCase
    test "reads call times without offset as UTC, like the result export" do
      user = users(:one)
      account_of(user).supplier_imports.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        response_payload: {
          "records" => [
            {
              "external_id" => "1",
              "client_name" => "Fornecedor Horário",
              "call_attempts" => [ { "attempt_number" => 1, "finished_at" => "2026-04-04T14:33:11.648146" } ]
            }
          ]
        }
      )

      entry = AuditEntriesService.new(account: account_of(user)).call.sole

      assert_equal "04/04/2026 11:33", entry.occurred_at.in_time_zone("America/Sao_Paulo").strftime("%d/%m/%Y %H:%M")
    end
  end
end
