module ValidationApi
  module SupplierDiscovery
    class DownloadResultsService < ValidationApi::AuthenticatedService
      def call(api_token:, search_id:)
        authorized_download(
          "/supplier-discovery/#{search_id}/results.xlsx",
          api_token: api_token
        )
      end
    end
  end
end
