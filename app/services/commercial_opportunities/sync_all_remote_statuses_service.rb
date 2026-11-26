module CommercialOpportunities
  class SyncAllRemoteStatusesService
    def call
      CommercialOpportunity.active_remote.includes(:account).find_each do |opportunity|
        SyncRemoteStatusService.new(
          account: opportunity.account,
          commercial_opportunity: opportunity
        ).call
      rescue ValidationApi::Error => e
        opportunity.update_columns(
          error_message: e.message,
          last_synced_at: Time.current,
          updated_at: Time.current
        )
        Rails.logger.warn("Falha ao sincronizar retorno comercial #{opportunity.id}: #{e.message}")
      rescue StandardError => e
        # Fronteira por item: um retorno com payload inesperado não interrompe os das demais empresas.
        Rails.error.report(e, handled: true, context: { commercial_opportunity_id: opportunity.id, account_id: opportunity.account_id })
        Rails.logger.error("Erro inesperado ao sincronizar retorno comercial #{opportunity.id} account_id=#{opportunity.account_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
