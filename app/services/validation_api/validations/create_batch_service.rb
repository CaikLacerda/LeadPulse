module ValidationApi
  module Validations
    class CreateBatchService < ValidationApi::AuthenticatedService
      def call(api_token:, payload:)
        authorized_post(
          '/validations',
          api_token: api_token,
          body: payload
        )
      end
    end
  end
end
