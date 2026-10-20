module SupplierImports
  class SyncAllRemoteStatusesService
    def call
      # Bounded post-completion window for late recordings, at most once per 15 minutes.
      recent = SupplierImport.where(status: [ SupplierImport::LOCAL_STATUS_COMPLETED, SupplierImport::LOCAL_STATUS_ERROR ])
        .where(finished_at: 24.hours.ago..Time.current)
        .where("last_synced_at IS NULL OR last_synced_at <= ?", RemoteEvidenceMerger::REFRESH_INTERVAL.ago)
        .where.not(remote_batch_id: [ nil, "" ])
      SupplierImport.active_remote.or(recent).includes(:account).find_each do |supplier_import|
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
      rescue StandardError => e
        # Fronteira por lote: um payload inesperado não pode interromper a sincronização
        # dos demais lotes, que são de todas as empresas.
        Rails.error.report(e, handled: true, context: { supplier_import_id: supplier_import.id, account_id: supplier_import.account_id })
        Rails.logger.error("Erro inesperado ao sincronizar lote #{supplier_import.id} account_id=#{supplier_import.account_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
