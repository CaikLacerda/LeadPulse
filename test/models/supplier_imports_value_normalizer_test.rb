require "test_helper"

class SupplierImportsValueNormalizerTest < ActiveSupport::TestCase
  test "normalizes numeric identifiers without trailing decimal" do
    assert_equal "19994110571", SupplierImports::ValueNormalizer.identifier(19_994_110_571.0)
    assert_equal "5511999999999", SupplierImports::ValueNormalizer.identifier("5511999999999.0")
    assert_equal "12345678000190", SupplierImports::ValueNormalizer.identifier(12_345_678_000_190.0)
  end

  test "preserves text values trimmed" do
    assert_equal "Adubo", SupplierImports::ValueNormalizer.text("  Adubo  ")
    assert_nil SupplierImports::ValueNormalizer.text("   ")
  end
end
