module CommercialOpportunities
  class SyncAllRemoteStatusesService
    def call
      CommercialOpportunity.active_remote.includes(:user).find_each do |opportunity|
        SyncRemoteStatusService.new(
          user: opportunity.user,
          commercial_opportunity: opportunity
        ).call
      rescue ValidationApi::Error => e
        opportunity.update_columns(
          error_message: e.message,
          last_synced_at: Time.current,
          updated_at: Time.current
        )
        Rails.logger.warn("Falha ao sincronizar retorno comercial #{opportunity.id}: #{e.message}")
      end
    end
  end
end
