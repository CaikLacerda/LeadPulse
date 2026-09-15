require "test_helper"

module ValidationApi
  class PathEncodingTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :requested_path

      def bearer_headers(token)
        { "Authorization" => "Bearer #{token}" }
      end

      def get(path, headers:, query: {})
        @requested_path = path
        { "headers" => headers, "query" => query }
      end
    end

    test "encodes remote identifiers as a single URL path segment" do
      client = FakeClient.new

      ValidationApi::Validations::ShowBatchService.new(client: client).call(
        api_token: "token-test",
        batch_id: "lote com espaço"
      )

      assert_equal "/validations/lote%20com%20espa%C3%A7o", client.requested_path
    end
  end
end
