module ValidationApi
  module Simulations
    # Cria uma execução na FastAPI (POST /simulations, responde 202 com a execução "queued").
    # A conversa roda em background na API; o Rails acompanha depois por polling.
    class CreateService < ValidationApi::AuthenticatedService
      def call(api_token:, target_type:, workflow_key:, scenario_key:, mode:, requested_by: nil)
        body = {
          target: { type: target_type, key: workflow_key },
          scenario_key: scenario_key,
          mode: mode
        }
        body[:requested_by] = requested_by if requested_by.present?

        authorized_post("/simulations", api_token: api_token, body: body)
      end
    end
  end
end
