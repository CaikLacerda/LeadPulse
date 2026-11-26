module ValidationApi
  module Simulations
    # Cancela a execução (POST /simulations/{id}/cancel, responde 202). Cancela na hora se ainda
    # está "queued"; se já está "running", sinaliza e o motor encerra na sequência.
    class CancelService < ValidationApi::AuthenticatedService
      def call(api_token:, remote_id:)
        authorized_post(
          "/simulations/#{escape_path_segment(remote_id)}/cancel",
          api_token: api_token
        )
      end
    end
  end
end
