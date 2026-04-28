module ValidationApi
  module SupplierValidations
    class CreateBatchService < ValidationApi::AuthenticatedService
      def call(api_token:, payload:)
        authorized_post(
          '/supplier-validations',
          api_token: api_token,
          body: payload
        )
      end
    end
  end
end
