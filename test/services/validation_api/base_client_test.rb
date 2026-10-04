require "test_helper"

module ValidationApi
  class BaseClientTest < ActiveSupport::TestCase
    STUB_URL = "http://validation-api.test".freeze

    teardown { Typhoeus::Expectation.clear }

    test "formats the API request validation response for the operator" do
      client = BaseClient.new
      payload = {
        "message" => "Payload inválido.",
        "errors" => [
          {
            "loc" => [ "body", "callback_phone" ],
            "msg" => "Value error, Telefone de retorno inválido para o padrão E.164 internacional."
          }
        ]
      }

      message = client.send(:error_message_for, payload, 422)

      assert_equal(
        "Payload inválido. Telefone de retorno: Telefone de retorno inválido para o padrão E.164 internacional.",
        message
      )
    end

    test "uses FastAPI detail messages when present" do
      client = BaseClient.new

      message = client.send(:error_message_for, { "detail" => "Token inválido." }, 401)

      assert_equal "Token inválido.", message
    end

    test "sends the current request id so both applications log the same id" do
      requests = capture_requests

      Current.set(request_id: "rails-req-123") do
        BaseClient.new(base_url: STUB_URL).get("/validations/lote", headers: { "Authorization" => "Bearer tkn" })
      end

      assert_equal "rails-req-123", requests.last.options[:headers]["X-Request-ID"]
      assert_equal "Bearer tkn", requests.last.options[:headers]["Authorization"]
    end

    test "does not send a request id outside a request or job" do
      requests = capture_requests

      BaseClient.new(base_url: STUB_URL).get("/validations/lote")

      assert_not requests.last.options[:headers].key?("X-Request-ID")
    end

    private

    def capture_requests
      requests = []
      Typhoeus.stub(%r{\A#{Regexp.escape(STUB_URL)}}) do |request|
        requests << request
        Typhoeus::Response.new(code: 200, body: "{}")
      end
      requests
    end
  end
end
