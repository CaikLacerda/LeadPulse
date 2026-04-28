module ValidationApi
  class AuthenticatedService < ApplicationService
    def initialize(client: ValidationApi::BaseClient.new)
      @client = client
    end

    private

    attr_reader :client

    def authorized_get(path, api_token:, query: {})
      client.get(path, headers: bearer_headers(api_token), query: query)
    end

    def authorized_post(path, api_token:, body: nil, query: {})
      client.post(path, headers: bearer_headers(api_token), body: body, query: query)
    end

    def authorized_put(path, api_token:, body: nil, query: {})
      client.put(path, headers: bearer_headers(api_token), body: body, query: query)
    end

    def authorized_download(path, api_token:, query: {})
      client.download(path, headers: bearer_headers(api_token), query: query)
    end

    def bearer_headers(api_token)
      client.bearer_headers(api_token)
    end
  end
end
