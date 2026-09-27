module Analytics
  # Agregados por registro (response_payload -> records). A data de referência é o início da
  # validação do lote. Taxas usam só registros com resultado: pending_dispatch e processing
  # ficam fora dos denominadores.
  class RecordsQuery < Query
    CALLED_STATUSES = %w[answered not_answered failed].freeze
    SERIES_KEYS = %i[records confirmed rejected inconclusive not_answered other].freeze

    def initialize(batches)
      @batches = batches
    end

    def summary
      row = select_one(<<~SQL)
        WITH batches AS (#{relation_sql(@batches, :id, :response_payload)}),
        records AS (
          SELECT si.id AS batch_id, r.record FROM batches si CROSS JOIN LATERAL #{records_of('si')} AS r(record)
        )
        SELECT
          (SELECT COUNT(*) FROM batches) AS batches,
          (SELECT COUNT(*) FROM batches b WHERE jsonb_array_length(#{Sql.array("b.response_payload -> 'records'")}) = 0) AS awaiting_sync,
          COUNT(*) AS records,
          COUNT(*) FILTER (WHERE record ->> 'final_status' = 'validated') AS validated,
          COUNT(*) FILTER (WHERE record ->> 'final_status' = 'validation_failed') AS not_validated,
          COUNT(*) FILTER (WHERE record ->> 'final_status' = 'processing') AS processing,
          #{CALL_RESULTS.map { |code| "COUNT(*) FILTER (WHERE record ->> 'call_result' = #{quote(code)}) AS #{code}" }.join(",\n  ")},
          COUNT(*) FILTER (WHERE record ->> 'call_result' IS NULL OR record ->> 'call_result' NOT IN (#{Sql.list(CALL_RESULTS)})) AS other_result,
          COUNT(*) FILTER (WHERE record ->> 'call_status' IN (#{Sql.list(CALLED_STATUSES)})) AS called,
          COUNT(*) FILTER (WHERE record ->> 'call_status' = 'answered') AS answered,
          COUNT(*) FILTER (
            WHERE record ->> 'privacy_refusal_detected' = 'true'
               OR EXISTS (SELECT 1 FROM #{attempts_of('records')} AS t(attempt) WHERE t.attempt ->> 'privacy_refusal_detected' = 'true')
          ) AS privacy_refusals,
          SUM(#{Sql.number("record ->> 'attempts_count'")}) AS attempts_sum,
          COUNT(#{Sql.number("record ->> 'attempts_count'")}) AS attempts_reported
        FROM records
      SQL

      {
        batches: integer(row["batches"]),
        awaiting_sync: integer(row["awaiting_sync"]),
        records: integer(row["records"]),
        validated: integer(row["validated"]),
        not_validated: integer(row["not_validated"]),
        processing: integer(row["processing"]),
        results: CALL_RESULTS.to_h { |code| [ code, integer(row[code]) ] }.merge("other" => integer(row["other_result"])),
        terminal: TERMINAL_RESULTS.sum { |code| integer(row[code]) },
        called: integer(row["called"]),
        answered: integer(row["answered"]),
        privacy_refusals: integer(row["privacy_refusals"]),
        attempts_sum: decimal(row["attempts_sum"]) || 0.0,
        attempts_reported: integer(row["attempts_reported"])
      }
    end

    # Registros por resultado em cada dia (ou semana) de início da validação.
    def series(window, grouping)
      rows = select_all(<<~SQL)
        SELECT #{Sql.bucket(Sql.column_time('si.validation_started_at'), grouping)} AS bucket,
          COUNT(*) AS records,
          #{TERMINAL_RESULTS.map { |code| "COUNT(*) FILTER (WHERE r.record ->> 'call_result' = #{quote(code)}) AS #{code}" }.join(",\n  ")},
          COUNT(*) FILTER (WHERE r.record ->> 'call_result' IS NULL OR r.record ->> 'call_result' NOT IN (#{Sql.list(TERMINAL_RESULTS)})) AS other
        FROM (#{relation_sql(@batches, :id, :response_payload, :validation_started_at)}) si
        CROSS JOIN LATERAL #{records_of('si')} AS r(record)
        GROUP BY 1
      SQL

      fill(rows, window.buckets(grouping), SERIES_KEYS)
    end
  end
end
