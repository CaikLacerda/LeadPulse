module ValidationApi
  module Simulations
    # Pede à FastAPI um ticket curto e somente-leitura para o navegador abrir o WebSocket de
    # áudio da simulação. Autentica com o token da empresa (o ticket devolvido NÃO carrega o
    # token). O Rails nunca repassa áudio; só intermedia a emissão do ticket.
    class AudioTicketService < ValidationApi::AuthenticatedService
      def call(api_token:, remote_id:)
        authorized_post(
          "/simulations/#{escape_path_segment(remote_id)}/audio-ticket",
          api_token: api_token
        )
      end
    end
  end
end
