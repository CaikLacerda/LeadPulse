module Api
  module V1
    module Mobile
      class CallsController < BaseController
        FIELDS = %w[client_name attempt_number status result duration_seconds].freeze
        before_action :require_evidence!
        before_action :require_integration!

        def index
          limit = integer_parameter(:limit, default: 50, minimum: 1, maximum: 200)
          offset = integer_parameter(:offset, default: 0, minimum: 0, maximum: 2_147_483_647)
          payload = ValidationApi::Mobile::CallsService.new.call(api_token:, period:, limit:, offset:)
          meta = metadata(payload)
          raise InvalidResponse unless payload["items"].is_a?(Array) && payload["total"].is_a?(Integer) && payload["total"] >= 0
          items = payload["items"].map do |item|
            raise InvalidResponse unless item.is_a?(Hash)
            item.slice(*FIELDS).merge("started_at" => timestamp(item["started_at"], optional: true),
              "finished_at" => timestamp(item["finished_at"], optional: true))
          end
          render json: meta.merge(total: payload["total"], limit:, offset:, items:)
        end

        private

        def require_evidence!
          render_error("forbidden", "Seu perfil não tem permissão para consultar chamadas.", :forbidden) unless membership.can_view_evidence?
        end
      end
    end
  end
end
