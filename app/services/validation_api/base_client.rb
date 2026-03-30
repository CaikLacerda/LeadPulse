require 'json'
require 'typhoeus'

module ValidationApi
  class BaseClient
    DEFAULT_BASE_URL = 'http://127.0.0.1:8000'.freeze
    DEFAULT_HEADERS = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }.freeze

    def initialize(base_url: ENV['VALIDATION_API_BASE_URL'].presence || DEFAULT_BASE_URL)
      @base_url = base_url.to_s.chomp('/')
      raise ValidationApi::Error, 'Defina VALIDATION_API_BASE_URL no ambiente do Rails.' if @base_url.blank?
    end

    def get(path, headers: {}, query: {})
      request(:get, path, headers:, params: query)
    end

    def post(path, body: nil, headers: {}, query: {})
      request(:post, path, body:, headers:, params: query)
    end

    def put(path, body: nil, headers: {}, query: {})
      request(:put, path, body:, headers:, params: query)
    end

    def download(path, headers: {}, query: {})
      response = request_response(:get, path, headers:, params: query)

      {
        body: response.body,
        content_type: response_header(response.headers, 'Content-Type'),
        content_disposition: response_header(response.headers, 'Content-Disposition')
      }
    end

    def admin_headers
      admin_key = ENV['PLATFORM_ADMIN_API_KEY'].to_s
      raise ValidationApi::Error, 'Defina PLATFORM_ADMIN_API_KEY no ambiente do Rails.' if admin_key.blank?

      DEFAULT_HEADERS.merge('X-Platform-Admin-Key' => admin_key)
    end

    def bearer_headers(token)
      raise ValidationApi::Error, 'Token da API do cliente não configurado.' if token.blank?

      DEFAULT_HEADERS.merge('Authorization' => "Bearer #{token}")
    end

    private

    def request(method, path, body: nil, headers: {}, params: {})
      response = request_response(method, path, body:, headers:, params:)
      parse_body(response.body)
    end

    def request_response(method, path, body: nil, headers: {}, params: {})
      response = Typhoeus::Request.new(
        "#{@base_url}#{path}",
        method: method,
        headers: DEFAULT_HEADERS.merge(headers),
        params: params.presence,
        body: body.nil? ? nil : JSON.generate(body),
        timeout: 20_000,
        connecttimeout: 5_000
      ).run

      if response.timed_out?
        raise ValidationApi::Error.new('Tempo esgotado ao chamar a API de validação.', status_code: 408)
      end

      if response.code.zero?
        raise ValidationApi::Error.new('Falha de conexão com a API de validação.', response_body: response.body)
      end

      return response if response.success?

      parsed_body = parse_body(response.body)
      detail = parsed_body.is_a?(Hash) ? parsed_body['detail'] : nil
      message = detail.presence || "A API de validação retornou erro HTTP #{response.code}."
      raise ValidationApi::Error.new(
        message,
        status_code: response.code,
        response_body: response.body,
        details: parsed_body
      )
    end

    def parse_body(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      { 'raw_body' => body }
    end

    def response_header(headers, key)
      if headers.respond_to?(:[])
        headers[key] || headers[key.downcase] || headers[key.upcase]
      else
        headers.to_s.lines.find { |line| line.downcase.start_with?("#{key.downcase}:") }&.split(':', 2)&.last&.strip
      end
    end
  end
end
