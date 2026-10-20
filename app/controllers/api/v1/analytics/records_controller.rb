module Api
  module V1
    module Analytics
      # GET /api/v1/analytics/records: um registro por item, dos lotes com validação
      # iniciada no período.
      class RecordsController < BaseController
        def index
          rows, next_cursor = ::Analytics::RecordsQuery.new(scope.validated_batches(filters.window)).page(after: cursor(3), limit: page_size)
          render_page(rows.map { |row| ::Analytics::RowPresenter.record(row) }, next_cursor)
        end
      end
    end
  end
end
