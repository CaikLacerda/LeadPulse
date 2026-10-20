module ValidationApi
  class PlatformAccountProvisioner
    def initialize(account, client: ValidationApi::BaseClient.new)
      @account = account
      @client = client
    end

    def ensure_account!
      return @account.validation_account_id if @account.validation_account_id.present?

      response = ValidationApi::PlatformAccounts::CreateService.new(client: @client).call(
        external_account_id: @account.validation_external_account_reference,
        company_name: @account.validation_company_name_value,
        spoken_company_name: @account.validation_spoken_company_name_value,
        owner_name: @account.validation_owner_name_value,
        owner_email: @account.validation_owner_email_value,
        calling_profile: @account.validation_calling_profile
      )

      persist_account_snapshot!(response)
      @account.validation_account_id
    end

    def persist_account_snapshot!(response)
      @account.update!(
        validation_account_id: response["id"],
        validation_external_account_id: response["external_account_id"].presence || @account.validation_external_account_reference,
        validation_company_name: response["company_name"].presence || @account.validation_company_name,
        validation_spoken_company_name: response["spoken_company_name"].presence || @account.validation_spoken_company_name,
        validation_owner_name: response["owner_name"].presence || @account.validation_owner_name,
        validation_owner_email: response["owner_email"].presence || @account.validation_owner_email,
        validation_calling_profile: response.key?("calling_profile") ? response["calling_profile"] : @account.validation_calling_profile,
        validation_account_response: response
      )
    end
  end
end
