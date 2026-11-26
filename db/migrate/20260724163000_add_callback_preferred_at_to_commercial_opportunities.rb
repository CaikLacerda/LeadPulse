class AddCallbackPreferredAtToCommercialOpportunities < ActiveRecord::Migration[8.1]
  def change
    add_column :commercial_opportunities, :callback_preferred_at, :datetime
  end
end
