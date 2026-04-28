module ValidationApi
  class PlatformAccountProvisioner
    def initialize(user, client: ValidationApi::BaseClient.new)
      @user = user
      @client = client
    end

    def ensure_account!
      return @user.validation_account_id if @user.validation_account_id.present?

      response = ValidationApi::PlatformAccounts::CreateService.new(client: @client).call(
        external_account_id: @user.validation_external_account_reference,
        company_name: @user.validation_company_name_value,
        spoken_company_name: @user.validation_spoken_company_name_value,
        owner_name: @user.validation_owner_name_value,
        owner_email: @user.validation_owner_email_value
      )

      persist_account_snapshot!(response)
      @user.validation_account_id
    end

    def persist_account_snapshot!(response)
      @user.update!(
        validation_account_id: response['id'],
        validation_external_account_id: response['external_account_id'].presence || @user.validation_external_account_reference,
        validation_company_name: response['company_name'].presence || @user.validation_company_name,
        validation_spoken_company_name: response['spoken_company_name'].presence || @user.validation_spoken_company_name,
        validation_owner_name: response['owner_name'].presence || @user.validation_owner_name,
        validation_owner_email: response['owner_email'].presence || @user.validation_owner_email,
        validation_account_response: response
      )
    end
  end
end
