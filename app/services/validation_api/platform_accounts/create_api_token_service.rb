module ValidationApi
  module PlatformAccounts
    class CreateApiTokenService
      def initialize(client: ValidationApi::BaseClient.new)
        @client = client
      end

      def call(account_id:, name:)
        @client.post(
          "/platform/accounts/#{account_id}/api-tokens",
          headers: @client.admin_headers,
          body: { name: name }
        )
      end
    end
  end
end
