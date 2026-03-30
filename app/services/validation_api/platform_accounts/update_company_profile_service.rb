module ValidationApi
  module PlatformAccounts
    class UpdateCompanyProfileService
      def initialize(client: ValidationApi::BaseClient.new)
        @client = client
      end

      def call(account_id:, company_name:, spoken_company_name:, owner_name:, owner_email:)
        @client.put(
          "/platform/accounts/#{account_id}/company-profile",
          headers: @client.admin_headers,
          body: {
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
