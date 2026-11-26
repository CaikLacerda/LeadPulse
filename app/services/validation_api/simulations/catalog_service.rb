module ValidationApi
  module Simulations
    # Alvos (workflows), modos e cenários disponíveis para simulação. O "available" de cada
    # modo vem da API; o Rails nunca decide isso.
    class CatalogService < ValidationApi::AuthenticatedService
      def call(api_token:)
        authorized_get("/simulations/catalog", api_token: api_token)
      end
    end
  end
end
