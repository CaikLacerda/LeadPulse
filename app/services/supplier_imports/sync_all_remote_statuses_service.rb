module SupplierImports
  class SyncAllRemoteStatusesService
    def call
      SupplierImport.active_remote.includes(:account).find_each do |supplier_import|
        SyncRemoteStatusService.new(
          account: supplier_import.account,
          supplier_import: supplier_import
        ).call
      rescue ValidationApi::Error => e
        supplier_import.update_columns(
          error_message: e.message,
          last_synced_at: Time.current,
          updated_at: Time.current
        )
        Rails.logger.warn("Falha ao sincronizar lote #{supplier_import.id}: #{e.message}")
      end
    end
  end
end
