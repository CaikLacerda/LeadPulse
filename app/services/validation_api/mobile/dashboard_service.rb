module ValidationApi
  module Mobile
    class DashboardService < ValidationApi::AuthenticatedService
      def call(api_token:, period:)
        authorized_get("/mobile/dashboard", api_token:, query: { period: })
      end
    end
  end
end
