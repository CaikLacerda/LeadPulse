module Analytics
  # Linha por lote com os agregados dos seus registros, e os indicadores de operação.
  # Ordenação só por colunas da lista permitida; agregação, ordem e paginação no SQL.
  #
  # Processamento usa o relógio da própria API (created_at → finished_at do payload), com a
  # regra de fuso de ValidationApi::Timestamp. Assim não depende da correção histórica de
  # finished_at nem de diferença entre o relógio local e o da API. Valor negativo é descartado.
  class BatchesQuery < Query
    PER_PAGE = 25
    SORTS = {
      "lote" => "id",
      "criado_em" => "created_at",
      "iniciado_em" => "validation_started_at",
      "registros" => "records",
      "validados" => "validated",
      "confirmados" => "confirmed",
      "taxa" => "confirmation_rate",
      "nao_atendidos" => "not_answered",
      "invalidas" => "invalid_rows",
      "processamento" => "processing_seconds"
    }.freeze
    DEFAULT_SORT = "criado_em".freeze

    Page = Data.define(:rows, :page, :total_pages, :total_count, :sort, :direction)

    def initialize(batches)
      @batches = batches
    end

    def page(sort: nil, direction: nil, page: 1, per_page: PER_PAGE)
      sort = SORTS.key?(sort) ? sort : DEFAULT_SORT
      direction = %w[asc desc].include?(direction) ? direction : "desc"
      total_count = integer(select_one("SELECT COUNT(*) AS total FROM (#{relation_sql(@batches, :id)}) si")["total"])
      total_pages = [ (total_count / per_page.to_f).ceil, 1 ].max
      page = page.to_i.clamp(1, total_pages)

      rows = select_all(<<~SQL)
        #{per_batch_cte}
        SELECT * FROM per_batch
        ORDER BY #{SORTS.fetch(sort)} #{direction.upcase} NULLS LAST, id DESC
        LIMIT #{per_page.to_i} OFFSET #{(page - 1) * per_page.to_i}
      SQL

      Page.new(rows: rows.map { |row| cast(row) }, page: page, total_pages: total_pages, total_count: total_count, sort: sort, direction: direction)
    end

    # Todas as linhas na ordem pedida, até o limite (exportação).
    def rows(sort: nil, direction: nil, limit: 50_000)
      sort = SORTS.key?(sort) ? sort : DEFAULT_SORT
      direction = %w[asc desc].include?(direction) ? direction : "desc"

      select_all(<<~SQL).map { |row| cast(row) }
        #{per_batch_cte}
        SELECT * FROM per_batch
        ORDER BY #{SORTS.fetch(sort)} #{direction.upcase} NULLS LAST, id DESC
        LIMIT #{limit.to_i}
      SQL
    end

    # Página de lotes em ordem de criação (created_at, id), a partir do cursor anterior.
    def page_after(after: nil, limit: 100)
      after_sql = "WHERE (created_at, id) > (#{quote(after[0])}::timestamp, #{after[1].to_i})" if after
      rows = select_all(<<~SQL).map { |row| cast(row) }
        #{per_batch_cte}
        SELECT * FROM per_batch #{after_sql}
        ORDER BY created_at, id
        LIMIT #{limit.to_i + 1}
      SQL
      next_cursor = ([ rows[limit - 1][:created_at].utc.iso8601(6), rows[limit - 1][:id] ] if rows.size > limit)
      [ rows.first(limit), next_cursor ]
    end

    def top(limit: 5)
      select_all(<<~SQL).map { |row| cast(row) }
        #{per_batch_cte}
        SELECT * FROM per_batch ORDER BY records DESC, id DESC LIMIT #{limit.to_i}
      SQL
    end

    def summary
      row = select_one(<<~SQL)
        #{per_batch_cte}
        SELECT
          COUNT(*) AS batches,
          COALESCE(SUM(records), 0) AS records,
          COALESCE(SUM(total_rows), 0) AS total_rows,
          COALESCE(SUM(invalid_rows), 0) AS invalid_rows,
          COUNT(wait_seconds) AS with_wait,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY wait_seconds) AS median_wait,
          COUNT(processing_seconds) AS with_processing,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY processing_seconds) AS median_processing,
          percentile_cont(0.9) WITHIN GROUP (ORDER BY processing_seconds) AS p90_processing
        FROM per_batch
      SQL

      {
        batches: integer(row["batches"]),
        records: integer(row["records"]),
        total_rows: integer(row["total_rows"]),
        invalid_rows: integer(row["invalid_rows"]),
        with_wait: integer(row["with_wait"]),
        median_wait: decimal(row["median_wait"]),
        with_processing: integer(row["with_processing"]),
        median_processing: decimal(row["median_processing"]),
        p90_processing: decimal(row["p90_processing"])
      }
    end

    private

    def per_batch_cte
      finished_at = "COALESCE(#{Sql.timestamp("si.response_payload ->> 'finished_at'")}, #{Sql.column_time('si.finished_at')})"
      remote_started_at = "COALESCE(#{Sql.timestamp("si.response_payload ->> 'created_at'")}, #{Sql.column_time('si.validation_started_at')})"

      <<~SQL
        WITH per_batch AS (
          SELECT
            si.id, si.workflow_kind, si.source, si.status, si.created_at, si.validation_started_at,
            COALESCE(si.total_rows, 0) AS total_rows,
            COALESCE(si.invalid_rows, 0) AS invalid_rows,
            agg.records, agg.validated, agg.confirmed, agg.terminal, agg.not_answered,
            agg.confirmed::numeric / NULLIF(agg.terminal, 0) AS confirmation_rate,
            NULLIF(GREATEST(EXTRACT(EPOCH FROM (si.validation_started_at - si.created_at)), -1), -1) AS wait_seconds,
            CASE WHEN si.finished_at IS NOT NULL OR si.response_payload ->> 'finished_at' IS NOT NULL THEN
              NULLIF(GREATEST(EXTRACT(EPOCH FROM (#{finished_at} - #{remote_started_at})), -1), -1)
            END AS processing_seconds
          FROM (#{relation_sql(@batches, *Scope::BATCH_COLUMNS)}) si
          CROSS JOIN LATERAL (
            SELECT
              COUNT(*) AS records,
              COUNT(*) FILTER (WHERE r.record ->> 'final_status' = 'validated') AS validated,
              COUNT(*) FILTER (WHERE r.record ->> 'call_result' = 'confirmed') AS confirmed,
              COUNT(*) FILTER (WHERE r.record ->> 'call_result' IN (#{Sql.list(TERMINAL_RESULTS)})) AS terminal,
              COUNT(*) FILTER (WHERE r.record ->> 'call_result' = 'not_answered') AS not_answered
            FROM #{records_of('si')} AS r(record)
          ) agg
        )
      SQL
    end

    def cast(row)
      {
        id: row["id"].to_i,
        workflow_kind: row["workflow_kind"],
        source: row["source"],
        status: row["status"],
        created_at: time(row["created_at"]),
        validation_started_at: time(row["validation_started_at"]),
        total_rows: integer(row["total_rows"]),
        invalid_rows: integer(row["invalid_rows"]),
        records: integer(row["records"]),
        validated: integer(row["validated"]),
        confirmed: integer(row["confirmed"]),
        terminal: integer(row["terminal"]),
        not_answered: integer(row["not_answered"]),
        wait_seconds: decimal(row["wait_seconds"]),
        processing_seconds: decimal(row["processing_seconds"])
      }
    end

    def time(value)
      return if value.blank?
      return value.in_time_zone if value.respond_to?(:in_time_zone) && !value.is_a?(String)

      Time.find_zone!("UTC").parse(value.to_s)&.in_time_zone
    end
  end
end
