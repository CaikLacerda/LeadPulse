require "uri"

module Security
  module ValidationWebsocketOrigin
    def self.value(**options)
      uri = URI.parse(base_url(**options))
      uri.path = ""
      uri.to_s
    end

    def self.base_url(env: ENV, production: Rails.env.production?)
      raw = env["VALIDATION_API_WS_BASE_URL"].presence || env["VALIDATION_API_BASE_URL"].presence || "http://127.0.0.1:8000"
      uri = URI.parse(raw.sub(/\Ahttp/, "ws"))
      valid = %w[ws wss].include?(uri.scheme) && uri.host.present? && !uri.host.include?("*") &&
        uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      valid &&= uri.scheme == "wss" if production
      raise ArgumentError, "Configure uma origem WebSocket válida; produção exige wss" unless valid

      uri.to_s.delete_suffix("/")
    rescue URI::InvalidURIError
      raise ArgumentError, "Origem WebSocket inválida"
    end
  end
end
