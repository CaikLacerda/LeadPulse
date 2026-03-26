class Supplier < ApplicationRecord
  belongs_to :supplier_import, optional: true
end