module Api
  module V1
    module Analytics
      # GET /api/v1/analytics/calls: uma tentativa de chamada por item, pelo horário da tentativa.
      class CallsController < BaseController
        def index
          query = ::Analytics::AttemptsQuery.new(scope.attempt_batches(filters.window), filters.window)
          rows, next_cursor = query.page(after: cursor(4), limit: page_size)
          render_page(rows.map { |row| ::Analytics::RowPresenter.attempt(row) }, next_cursor)
        end
      end
    end
  end
end
