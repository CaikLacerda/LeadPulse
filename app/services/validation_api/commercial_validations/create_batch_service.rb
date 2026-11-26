module ValidationApi
  module CommercialValidations
    class CreateBatchService < ValidationApi::AuthenticatedService
      def call(api_token:, payload:)
        authorized_post(
          "/commercial-validations",
          api_token: api_token,
          body: payload
        )
      end
    end
  end
end
