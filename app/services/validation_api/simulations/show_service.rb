module ValidationApi
  module Simulations
    # Estado completo da execução: status, resultado, avaliação, transcript e diagnóstico.
    # Lido ao abrir a tela e de novo quando a execução termina (para o relatório final).
    class ShowService < ValidationApi::AuthenticatedService
      def call(api_token:, remote_id:)
        authorized_get("/simulations/#{escape_path_segment(remote_id)}", api_token: api_token)
      end
    end
  end
end
