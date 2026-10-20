module ValidationApi
  module SupplierDiscovery
    class CreateSearchService < ValidationApi::AuthenticatedService
      def call(api_token:, payload:)
        authorized_post(
          "/supplier-discovery",
          api_token: api_token,
          body: payload,
          timeout_ms: 120_000
        )
      end
    end
  end
end
