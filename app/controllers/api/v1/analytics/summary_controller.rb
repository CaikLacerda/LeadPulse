module Api
  module V1
    module Analytics
      # GET /api/v1/analytics/summary: indicadores do período e da comparação, com o n de
      # cada um. A variação só vem quando é conclusiva (amostra de 20 ou mais nos dois lados);
      # comparison_status explica quando não vem.
      class SummaryController < BaseController
        METRICS = {
          "records" => [ :overview, :summary, :records ],
          "validation_rate" => [ :overview, :summary, :validation_rate ],
          "confirmation_rate" => [ :overview, :summary, :confirmation_rate ],
          "batches_started" => [ :overview, :summary, :batches ],
          "attempts" => [ :calls, :summary, :attempts ],
          "answered_attempts" => [ :calls, :summary, :answered ],
          "answer_rate" => [ :calls, :summary, :answer_rate ],
          "median_answered_duration_seconds" => [ :calls, :summary, :median_duration ],
          "average_answered_duration_seconds" => [ :calls, :summary, :average_duration ],
          "answered_duration_coverage" => [ :calls, :summary, :duration_coverage ],
          "qualified_records" => [ :qualification, :summary, :qualified ],
          "qualification_rate" => [ :qualification, :summary, :qualification_rate ],
          "commercial_opportunities" => [ :qualification, :summary, :opportunities ],
          "collected_opportunities" => [ :qualification, :summary, :collected ],
          "supplier_searches" => [ :qualification, :searches, :searches ],
          "batches_created" => [ :batches, :summary, :batches ],
          "invalid_row_rate" => [ :batches, :summary, :invalid_rate ],
          "median_wait_seconds" => [ :batches, :summary, :median_wait ],
          "median_processing_seconds" => [ :batches, :summary, :median_processing ],
          "p90_processing_seconds" => [ :batches, :summary, :p90_processing ]
        }.freeze
        CHANGE_UNITS = { count: "ratio", rate: "percentage_points", duration: "seconds" }.freeze

        def show
          report = ::Analytics::Report.new(scope: scope)
          pages = {}
          unavailable = []
          metrics = METRICS.to_h do |name, (page, section_name, key)|
            section = (pages[page] ||= report.public_send(page))[section_name]
            unavailable << name if section.failed?
            [ name, section.failed? ? nil : metric(section.data[:metrics].fetch(key)) ]
          end

          previous = filters.previous_window
          render json: {
            data: { metrics: metrics },
            meta: meta.merge(
              comparison_period: (previous && { from: previous.first_day.iso8601, to: previous.last_day.iso8601 }),
              min_sample: ::Analytics::Metric::MIN_SAMPLE,
              unavailable_metrics: unavailable
            )
          }
        end

        private

        def metric(comparison)
          current = comparison.current
          previous = comparison.previous
          conclusive = comparison.conclusive?
          delta = comparison.delta if conclusive
          delta *= 100 if delta && current.kind == :rate

          {
            value: rounded(current.value),
            unit: { count: "count", rate: "ratio", duration: "seconds" }.fetch(current.kind, "number"),
            sample: current.sample,
            low_sample: current.low_sample?,
            previous: (previous && { value: rounded(previous.value), sample: previous.sample }),
            change: rounded(delta),
            change_unit: (CHANGE_UNITS[current.kind] if delta),
            comparison_status: comparison.status.to_s
          }
        end

        def rounded(value)
          value.is_a?(Float) ? value.round(4) : value
        end
      end
    end
  end
end
