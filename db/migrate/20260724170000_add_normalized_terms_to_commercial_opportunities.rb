class AddNormalizedTermsToCommercialOpportunities < ActiveRecord::Migration[8.1]
  def change
    add_column :commercial_opportunities, :normalized_product_specification, :text
    add_column :commercial_opportunities, :normalized_unit_price, :text
    add_column :commercial_opportunities, :normalized_lot_price_ranges, :text
    add_column :commercial_opportunities, :normalized_minimum_order, :text
    add_column :commercial_opportunities, :normalization_source, :string
  end
end
