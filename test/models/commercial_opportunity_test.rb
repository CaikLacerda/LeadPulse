require "test_helper"

class CommercialOpportunityTest < ActiveSupport::TestCase
  test "allows refreshing a completed remote collection" do
    opportunity = CommercialOpportunity.new(
      status: CommercialOpportunity::STATUS_COMPLETED,
      remote_batch_id: "commercial-batch-1",
      started_at: Time.current
    )

    assert opportunity.syncable?
  end

  test "uses normalized commercial terms without losing original answers" do
    opportunity = CommercialOpportunity.new(
      product_specification: "A PLATA Technology.",
      unit_price: "Estamos estabelecidos por cento e cinquenta reais.",
      lot_price_ranges: "Uma faixa de dez unidades fica mil reais.",
      minimum_order: "O pedido mínimo é uma unidade só.",
      normalized_product_specification: "PLATA Technology",
      normalized_unit_price: "R$ 150,00 por unidade",
      normalized_lot_price_ranges: "10 unidades: R$ 1.000,00 por lote",
      normalized_minimum_order: "1 unidade"
    )

    assert_equal "PLATA Technology", opportunity.display_product_specification
    assert_equal "R$ 150,00 por unidade", opportunity.display_unit_price
    assert_equal "10 unidades: R$ 1.000,00 por lote", opportunity.display_lot_price_ranges
    assert_equal "1 unidade", opportunity.display_minimum_order
    assert opportunity.original_commercial_terms_differ?
    assert_equal "Estamos estabelecidos por cento e cinquenta reais.", opportunity.unit_price
  end

  test "requires one source record per supplier import" do
    user = users(:one)
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    attributes = {
      user: user,
      supplier_import: supplier_import,
      source_external_id: "supplier-1",
      supplier_name: "Fornecedor Exemplo",
      callback_phone: "+5511987654321"
    }

    CommercialOpportunity.create!(attributes)
    duplicate = CommercialOpportunity.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors[:source_external_id].present?
  end
end
