require "test_helper"

module SupplierImports
  class PrivacyRefusalRegistryTest < ActiveSupport::TestCase
    test "blocks the normalized phone returned by the validation API" do
      user = User.create!(
        name: "Operação LGPD",
        email: "privacy-registry@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        response_payload: {
          "records" => [
            {
              "phone_original" => "(19) 99999-0000",
              "phone_normalized" => "+5519999990000",
              "privacy_refusal_detected" => true,
              "call_attempts" => [
                { "phone_dialed" => "+5519999990000" }
              ]
            }
          ]
        }
      )

      blocked_numbers = PrivacyRefusalRegistry.blocked_phone_numbers_for(user)

      assert PrivacyRefusalRegistry.blocked?("19 99999-0000", blocked_numbers)
      assert_includes blocked_numbers, "+5519999990000"
    end
  end
end
