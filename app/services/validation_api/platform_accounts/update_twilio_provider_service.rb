module ValidationApi
  module PlatformAccounts
    class UpdateTwilioProviderService
      def initialize(client: ValidationApi::BaseClient.new)
        @client = client
      end

      def call(account_id:, account_sid:, auth_token:, webhook_base_url:, phone_numbers:)
        @client.put(
          "/platform/accounts/#{account_id}/providers/twilio",
          headers: @client.admin_headers,
          body: {
            account_sid: account_sid,
            auth_token: auth_token,
            webhook_base_url: webhook_base_url.presence,
            phone_numbers: phone_numbers
          }
        )
      end
    end
  end
end
