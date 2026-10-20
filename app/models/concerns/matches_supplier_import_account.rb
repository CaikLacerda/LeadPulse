# Registros ligados a um lote pertencem à mesma empresa do lote: herdam a conta quando
# ela não é informada e são recusados se vierem com uma conta diferente.
module MatchesSupplierImportAccount
  extend ActiveSupport::Concern

  included do
    before_validation :inherit_account_from_supplier_import
    validate :supplier_import_belongs_to_account
  end

  private

  def inherit_account_from_supplier_import
    self.account ||= supplier_import&.account
  end

  def supplier_import_belongs_to_account
    return if supplier_import.blank? || account_id.blank?
    return if supplier_import.account_id == account_id

    errors.add(:supplier_import, "deve pertencer à mesma conta")
  end
end
