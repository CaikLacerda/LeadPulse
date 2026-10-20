module Api
  module V1
    module Mobile
      # API do aplicativo: sessão pessoal lpm_, vínculo ativo e empresa resolvida no servidor.
      # O token da FastAPI fica no Rails. Só agregados e evidências autorizadas, sem telefones,
      # atravessam esta fronteira. Não aceita tokens de BI nem tokens diretos da integração.
      class BaseController < ActionController::API
        include ActionController::HttpAuthentication::Token::ControllerMethods

        PERIODS = %w[24h week month].freeze
        RATE_LIMIT_STORE = Rails.cache.is_a?(ActiveSupport::Cache::NullStore) ? ActiveSupport::Cache::MemoryStore.new : Rails.cache
        class InvalidParameter < StandardError; end
        class InvalidResponse < StandardError; end

        rate_limit to: 120, within: 1.minute, by: -> { request.remote_ip },
          with: -> { rate_limited(60) }, store: RATE_LIMIT_STORE, scope: "mobile_api"
        before_action { Current.request_id = request.request_id }
        before_action :authenticate_session!
        before_action :prevent_caching

        rescue_from InvalidParameter do |error|
          render_error("invalid_parameter", error.message, :bad_request)
        end
        rescue_from InvalidResponse do
          render_error("integration_invalid_response", "A integração retornou dados inválidos. Tente de novo.", :bad_gateway)
        end
        rescue_from ValidationApi::Error, with: :integration_error

        private

        attr_reader :mobile_session, :membership

        def current_account
          mobile_session.account
        end

        def authenticate_session!
          @mobile_session = authenticate_with_http_token { |token, _| MobileSession.authenticate(token) }
          unless mobile_session
            response.headers["WWW-Authenticate"] = 'Bearer realm="LeadPulse Mobile"'
            return render_error("unauthorized", "Sua sessão expirou. Entre novamente.", :unauthorized)
          end

          @membership = mobile_session.user.account_memberships.active.find_by(account: current_account)
          render_error("membership_inactive", "Seu acesso à empresa está desativado.", :forbidden) unless membership
        end

        def prevent_caching
          response.headers["Cache-Control"] = "no-store"
        end

        def period
          @period ||= begin
            value = params.fetch(:period, "month")
            raise InvalidParameter, "Escolha o período 24h, week ou month." unless PERIODS.include?(value)
            value
          end
        end

        def require_integration!
          return if current_account.validation_api_token_configured?

          render_error("integration_not_configured", "A integração da empresa ainda não foi configurada. Fale com o administrador.", :conflict)
        end

        def api_token
          current_account.validation_api_token_value
        end

        def timestamp(value, optional: false)
          return if value.nil? && optional

          parsed = ValidationApi::Timestamp.parse(value)
          raise InvalidResponse unless parsed
          parsed.utc.iso8601(6)
        end

        def metadata(payload)
          raise InvalidResponse unless payload.is_a?(Hash) && payload["period"] == period

          { period:, window_start: timestamp(payload["window_start"]),
            window_end: timestamp(payload["window_end"]), generated_at: timestamp(payload["generated_at"]) }
        end

        def integer_parameter(name, default:, minimum:, maximum:)
          raw = params.fetch(name, default).to_s
          value = raw.match?(/\A\d{1,10}\z/) ? raw.to_i : nil
          raise InvalidParameter, "#{name} deve estar entre #{minimum} e #{maximum}." unless value && value.between?(minimum, maximum)
          value
        end

        def render_error(code, message, status)
          response.headers["Cache-Control"] = "no-store"
          render json: { error: { code:, message: } }, status:
        end

        def rate_limited(seconds)
          response.headers["Retry-After"] = seconds.to_s
          render_error("rate_limited", "Muitas tentativas. Aguarde e tente de novo.", :too_many_requests)
        end

        def integration_error(error)
          case error.status_code
          when 401, 403
            render_error("integration_token_invalid", "A integração da empresa precisa ser reconectada pelo administrador.", :conflict)
          when 408, 504
            render_error("integration_timeout", "A integração demorou para responder. Tente de novo.", :gateway_timeout)
          when 429
            render_error("integration_rate_limited", "A integração está ocupada. Tente novamente em instantes.", :service_unavailable)
          else
            render_error("integration_unavailable", "Não foi possível consultar a integração. Tente de novo.", :bad_gateway)
          end
        end
      end
    end
  end
end
