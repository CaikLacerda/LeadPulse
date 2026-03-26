class SupplierImport < ApplicationRecord
  belongs_to :user
  has_many :supplier_import
  has_many :supplier_import_versions
end