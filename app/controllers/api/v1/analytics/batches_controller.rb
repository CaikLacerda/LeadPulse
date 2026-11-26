module Api
  module V1
    module Analytics
      # GET /api/v1/analytics/batches: um lote por item, dos lotes criados no período.
      class BatchesController < BaseController
        def index
          rows, next_cursor = ::Analytics::BatchesQuery.new(scope.created_batches(filters.window)).page_after(after: cursor(2), limit: page_size)
          render_page(rows.map { |row| ::Analytics::RowPresenter.batch(row) }, next_cursor)
        end
      end
    end
  end
end
