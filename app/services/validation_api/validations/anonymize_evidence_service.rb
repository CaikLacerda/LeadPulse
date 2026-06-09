module ValidationApi
  module Validations
    class AnonymizeEvidenceService < ValidationApi::AuthenticatedService
      def call(api_token:, batch_id:)
        authorized_post(
          "/validations/#{batch_id}/evidence/anonymize",
          api_token: api_token
        )
      end
    end
  end
end
