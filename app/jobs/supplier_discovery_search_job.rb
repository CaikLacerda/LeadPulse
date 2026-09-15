class SupplierDiscoverySearchJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(search)
    search.with_lock do
      return if search.completed?

      search.update!(
        status: SupplierDiscoverySearch::LOCAL_STATUS_PROCESSING,
        error_message: nil
      )
    end

    result = remote_search_service(search).call
    return log_failure(result) unless result.success?

    PrivacyAudit::Logger.log!(
      user: search.user,
      action: "supplier_discovery_created",
      resource: search,
      metadata: {
        segment_name: search.segment_name,
        region: search.region,
        total_suppliers: search.total_suppliers
      }
    )
  end

  private

  def remote_search_service(search)
    SupplierDiscoverySearches::CreateRemoteSearchService.new(search:)
  end

  def log_failure(result)
    Rails.logger.warn(
      "Supplier discovery background job failed | " \
      "search_id=#{result.search&.id} error=#{result.error_message}"
    )
  end
end
