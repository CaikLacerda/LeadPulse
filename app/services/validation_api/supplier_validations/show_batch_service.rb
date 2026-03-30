module ValidationApi
  module SupplierValidations
    class ShowBatchService < ValidationApi::AuthenticatedService
      def call(api_token:, batch_id:)
        authorized_get(
          "/supplier-validations/#{batch_id}",
          api_token: api_token
        )
      end
    end
  end
end
