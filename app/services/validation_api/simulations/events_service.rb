module ValidationApi
  module Simulations
    # Linha do tempo da execução a partir de um seq (after). O cliente começa com after=0 e
    # usa o next_after de cada resposta como o próximo after.
    class EventsService < ValidationApi::AuthenticatedService
      def call(api_token:, remote_id:, after: 0, limit: 200)
        authorized_get(
          "/simulations/#{escape_path_segment(remote_id)}/events",
          api_token: api_token,
          query: { after: after.to_i, limit: limit.to_i }
        )
      end
    end
  end
end
