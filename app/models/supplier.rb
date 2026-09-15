class Supplier < ApplicationRecord
  belongs_to :supplier_import, optional: true

  validates :name, :company_name, presence: true
end
