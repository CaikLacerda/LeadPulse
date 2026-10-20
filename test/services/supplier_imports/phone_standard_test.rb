require "test_helper"

module SupplierImports
  class PhoneStandardTest < ActiveSupport::TestCase
    test "normalizes Brazilian supplier phones with country code" do
      assert_equal "+5511999999999", PhoneStandard.e164("(11) 99999-9999")
    end

    test "normalizes international callback without adding Brazilian country code" do
      assert_equal "+13527176703", PhoneStandard.callback_e164("13527176703")
      assert_equal "+13527176703", PhoneStandard.callback_e164("+1 (352) 717-6703")
    end

    test "keeps Brazilian callback normalization for national numbers" do
      assert_equal "+5511999999999", PhoneStandard.callback_e164("11 99999-9999")
    end
  end
end
