require "test_helper"

module ValidationApi
  class BaseClientTest < ActiveSupport::TestCase
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
  end
end
