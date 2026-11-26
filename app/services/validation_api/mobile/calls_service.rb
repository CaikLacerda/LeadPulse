module ValidationApi
  module Mobile
    class CallsService < ValidationApi::AuthenticatedService
      def call(api_token:, period:, limit:, offset:)
        authorized_get("/mobile/calls", api_token:, query: { period:, limit:, offset: })
      end
    end
  end
end
