module ValidationApi
  module PlatformAccounts
    class CreateService
      def initialize(client: ValidationApi::BaseClient.new)
        @client = client
      end

      def call(external_account_id:, company_name:, spoken_company_name:, owner_name:, owner_email:)
        @client.post(
          '/platform/accounts',
          headers: @client.admin_headers,
          body: {
            external_account_id: external_account_id,
            company_name: company_name,
            spoken_company_name: spoken_company_name,
            owner_name: owner_name,
            owner_email: owner_email
          }
        )
      end
    end
  end
end
