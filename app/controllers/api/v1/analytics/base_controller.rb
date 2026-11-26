module Api
  module V1
    module Analytics
      # Base da API de Analytics (somente leitura) para BI: Power BI, Tableau, Excel Power
      # Query ou qualquer cliente HTTP.
      #
      # - Autenticação: "Authorization: Bearer lpbi_..." (token de BI da empresa). O token
      #   define a empresa; toda consulta passa por ::Analytics::Scope dessa empresa.
      # - Filtros: from/to (datas YYYY-MM-DD, dias inteiros em America/Sao_Paulo, até 366
      #   dias; padrão: últimos 30), workflow_kind, source, batch_id e, em /batches, status.
      #   Valor inválido responde 400; lote de outra empresa responde 404.
      # - Paginação por cursor: page[size] (padrão 100, máximo 500) e page[after].
      # - Limite de requisições por token; acima dele, 429 com Retry-After.
      class BaseController < ActionController::API
        include ActionController::HttpAuthentication::Token::ControllerMethods

        DEFAULT_PAGE_SIZE = 100
        MAX_PAGE_SIZE = 500
        RATE_LIMIT_WINDOW = 1.minute
        RATE_LIMIT_STORE = Rails.cache.is_a?(ActiveSupport::Cache::NullStore) ? ActiveSupport::Cache::MemoryStore.new : Rails.cache
        COMPARISONS = {
          "previous_period" => ::Analytics::Filters::COMPARE_PREVIOUS,
          "previous_year" => ::Analytics::Filters::COMPARE_PREVIOUS_YEAR,
          "none" => ::Analytics::Filters::COMPARE_NONE
        }.freeze

        class InvalidParameter < StandardError; end

        rate_limit to: Rails.configuration.x.analytics_api_rate_limit || 120, within: RATE_LIMIT_WINDOW,
          by: -> { rate_limit_key }, with: -> { too_many_requests }, store: RATE_LIMIT_STORE, scope: "analytics_api"
        before_action :authenticate_api_token!
        after_action :log_access

        rescue_from InvalidParameter do |error|
          render json: { error: { code: "invalid_parameter", message: error.message } }, status: :bad_request
        end

        rescue_from ActiveRecord::RecordNotFound do
          render json: { error: { code: "not_found", message: "Resource not found." } }, status: :not_found
        end

        private

        attr_reader :api_token

        def current_account
          api_token.account
        end

        def authenticate_api_token!
          @api_token = authenticate_with_http_token { |token, _options| AnalyticsApiToken.authenticate(token) }
          if @api_token
            @api_token.touch_last_used!
          else
            response.headers["WWW-Authenticate"] = 'Bearer realm="LeadPulse Analytics"'
            render json: { error: { code: "unauthorized", message: "Missing, invalid or revoked token." } }, status: :unauthorized
          end
        end

        def rate_limit_key
          token = request.authorization.to_s.delete_prefix("Bearer ").strip
          token.present? ? AnalyticsApiToken.digest(token) : request.remote_ip
        end

        def too_many_requests
          response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
          render json: { error: { code: "rate_limited", message: "Too many requests. Try again later." } }, status: :too_many_requests
        end

        def filters
          @filters ||= ::Analytics::Filters.new(filter_params, account: current_account)
        end

        def scope
          @scope ||= ::Analytics::Scope.new(account: current_account, filters: filters)
        end

        def filter_params
          from = parse_date(:from)
          to = parse_date(:to)
          raise InvalidParameter, "from and to must be sent together." if from.nil? ^ to.nil?
          raise InvalidParameter, "from must be on or before to." if from && from > to
          raise InvalidParameter, "The period can have at most #{::Analytics::Filters::MAX_CUSTOM_DAYS} days." if from && (to - from).to_i + 1 > ::Analytics::Filters::MAX_CUSTOM_DAYS

          {
            periodo: from ? ::Analytics::Filters::PERIOD_CUSTOM : ::Analytics::Filters::DEFAULT_PERIOD,
            de: from&.iso8601,
            ate: to&.iso8601,
            comparar: choice(:compare, COMPARISONS, default: "previous_period"),
            fluxo: choice(:workflow_kind, ::Analytics::Filters::WORKFLOW_KINDS),
            origem: choice(:source, ::Analytics::Filters::SOURCES),
            status: choice(:status, ::Analytics::Filters::STATUSES),
            lote: batch_id
          }
        end

        def parse_date(key)
          return if params[key].blank?

          Date.iso8601(params[key].to_s)
        rescue Date::Error
          raise InvalidParameter, "#{key} must be a date in the format YYYY-MM-DD."
        end

        def choice(key, allowed, default: nil)
          value = params[key].presence || default
          return if value.nil?

          allowed = allowed.to_h { |item| [ item, item ] } if allowed.is_a?(Array)
          allowed.fetch(value.to_s) { raise InvalidParameter, "#{key} must be one of: #{allowed.keys.join(', ')}." }
        end

        def batch_id
          return if params[:batch_id].blank?

          id = params[:batch_id].to_s[/\A\d{1,18}\z/] or raise InvalidParameter, "batch_id must be an integer."
          current_account.supplier_imports.find(id).id
        end

        def page_size
          size = params.dig(:page, :size).presence || DEFAULT_PAGE_SIZE
          size = Integer(size.to_s, exception: false)
          raise InvalidParameter, "page[size] must be an integer between 1 and #{MAX_PAGE_SIZE}." unless size&.positive?

          [ size, MAX_PAGE_SIZE ].min
        end

        def cursor(parts)
          raw = params.dig(:page, :after)
          return if raw.blank?

          values = JSON.parse(Base64.urlsafe_decode64(raw.to_s))
          valid = values.is_a?(Array) && values.size == parts && values.first.is_a?(String) && values.drop(1).all?(Integer)
          valid &&= Time.iso8601(values.first)
          raise InvalidParameter, "page[after] is not a valid cursor." unless valid

          values
        rescue ArgumentError, JSON::ParserError
          raise InvalidParameter, "page[after] is not a valid cursor."
        end

        def encode_cursor(values)
          Base64.urlsafe_encode64(JSON.generate(values), padding: false) if values
        end

        def render_page(data, next_cursor)
          next_token = encode_cursor(next_cursor)
          render json: {
            data: data,
            meta: meta.merge(page_size: page_size, next_cursor: next_token),
            links: { next: (url_for(request.query_parameters.merge(page: { size: page_size, after: next_token }, only_path: false)) if next_token) }
          }
        end

        def meta
          {
            period: { from: filters.window.first_day.iso8601, to: filters.window.last_day.iso8601, time_zone: ::Analytics::Sql::TIME_ZONE },
            filters: { workflow_kind: filters.workflow_kind, source: filters.source, batch_id: filters.supplier_import_id, status: filters.status }.compact,
            generated_at: Time.current.utc.iso8601
          }
        end

        # Um evento por extração (primeira página), para não encher a trilha a cada página.
        def log_access
          return unless api_token && response.successful? && params.dig(:page, :after).blank?

          PrivacyAudit::Logger.log!(
            account: current_account,
            user: api_token.created_by,
            action: "analytics_api_accessed",
            resource: api_token,
            metadata: { endpoint: action_path, token_prefix: api_token.token_prefix, filters: meta[:filters], period: meta[:period].slice(:from, :to) }
          )
        end

        def action_path
          request.path.delete_prefix("/api/v1/analytics/")
        end
      end
    end
  end
end
