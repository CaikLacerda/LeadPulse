module ValidationApi
  module PlatformAccounts
    class UpdateOpenaiProviderService
      def initialize(client: ValidationApi::BaseClient.new)
        @client = client
      end

      def call(account_id:, api_key:, realtime_model:, realtime_voice:, realtime_output_speed:, realtime_style_instructions:)
        @client.put(
          "/platform/accounts/#{account_id}/providers/openai",
          headers: @client.admin_headers,
          body: {
            api_key: api_key,
            realtime_model: realtime_model,
            realtime_voice: realtime_voice,
            realtime_output_speed: realtime_output_speed.presence,
            realtime_style_instructions: realtime_style_instructions.presence
          }
        )
      end
    end
  end
end
