module Api
  module V1
    module Mobile
      class DashboardController < BaseController
        SUMMARY_FIELDS = %w[total_batches completed_batches processing_batches total_records confirmed_records
          commercial_returns total_call_attempts answered_calls not_answered_calls failed_calls confirmed_calls
          rejected_calls inconclusive_calls answer_rate_percent confirmation_rate_percent
          average_call_duration_seconds total_call_duration_seconds].freeze
        before_action :require_integration!

        def show
          payload = ValidationApi::Mobile::DashboardService.new.call(api_token:, period:)
          meta = metadata(payload)
          summary = payload["summary"]
          raise InvalidResponse unless summary.is_a?(Hash) && SUMMARY_FIELDS.all? { |key| summary[key].is_a?(Numeric) && summary[key] >= 0 }

          render json: meta.merge(summary: summary.slice(*SUMMARY_FIELDS), series: build_series(meta))
        end

        private

        def build_series(meta)
          start_time = Time.iso8601(meta[:window_start]).in_time_zone("America/Sao_Paulo")
          end_time = Time.iso8601(meta[:window_end]).in_time_zone("America/Sao_Paulo")
          raise InvalidResponse unless end_time >= start_time && end_time - start_time <= 31.days

          hourly = period == "24h"
          cursor = hourly ? start_time.beginning_of_hour : start_time.beginning_of_day
          buckets = {}
          while cursor <= end_time
            buckets[cursor.utc.iso8601] = { at: cursor.utc.iso8601, attempts: 0, answered: 0 }
            cursor += hourly ? 1.hour : 1.day
          end

          scanned = 0
          total = 0
          undated = 0
          # shortcut: até 2.000 chamadas / 10 páginas; a série sinaliza truncamento. Em produção,
          # preferir agregação na FastAPI para evitar até 11 consultas por dashboard e drift entre páginas.
          10.times do
            page = ValidationApi::Mobile::CallsService.new.call(api_token:, period:, limit: 200, offset: scanned)
            raise InvalidResponse unless page.is_a?(Hash) && page["items"].is_a?(Array) && page["total"].is_a?(Integer) && page["total"] >= 0
            items = page["items"]
            raise InvalidResponse if items.size > 200
            total = page["total"]
            items.each do |item|
              raise InvalidResponse unless item.is_a?(Hash)
              time = ValidationApi::Timestamp.parse(item["started_at"] || item["finished_at"])
              unless time
                undated += 1
                next
              end
              next unless time.between?(start_time, end_time)
              local = time.in_time_zone("America/Sao_Paulo")
              key = (hourly ? local.beginning_of_hour : local.beginning_of_day).utc.iso8601
              bucket = buckets.fetch(key)
              bucket[:attempts] += 1
              bucket[:answered] += 1 if item["status"] == "answered"
            end
            scanned += items.size
            break if scanned >= total || items.empty?
          end
          { interval: hourly ? "hour" : "day", time_zone: "America/Sao_Paulo",
            truncated: scanned < total, undated_calls: undated, points: buckets.values }
        end
      end
    end
  end
end
