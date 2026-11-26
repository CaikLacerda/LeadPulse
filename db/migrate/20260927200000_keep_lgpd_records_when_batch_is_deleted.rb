# A trilha LGPD e as solicitações de titulares sobrevivem à exclusão do lote: a referência
# ao lote vira nula, e o evento mantém o código do lote nos metadados. Antes, excluir um
# lote que já tinha sido exportado falhava com violação de chave estrangeira.
class KeepLgpdRecordsWhenBatchIsDeleted < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :privacy_audit_events, :supplier_imports
    add_foreign_key :privacy_audit_events, :supplier_imports, on_delete: :nullify

    remove_foreign_key :privacy_requests, :supplier_imports
    add_foreign_key :privacy_requests, :supplier_imports, on_delete: :nullify
  end
end
