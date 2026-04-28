module SupplierImports
  class SyncAllRemoteStatusesService
    def call
      SupplierImport.active_remote.includes(:user).find_each do |supplier_import|
        next if supplier_import.user.blank?

        SyncRemoteStatusService.new(
          user: supplier_import.user,
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
