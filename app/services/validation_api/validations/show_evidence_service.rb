module ValidationApi
  module Validations
    # GET /validations/:batch_id/evidence: tentativas de chamada, turnos, gravações e validade
    # das evidências de um lote, paginado (limit até 200).
    class ShowEvidenceService < ValidationApi::AuthenticatedService
      def call(api_token:, batch_id:, limit:, offset:)
        authorized_get(
          "/validations/#{escape_path_segment(batch_id)}/evidence",
          api_token: api_token,
          query: { limit: limit, offset: offset }
        )
      end
    end
  end
end
