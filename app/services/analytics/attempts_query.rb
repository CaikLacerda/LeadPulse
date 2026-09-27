module Analytics
  # Agregados por tentativa de chamada (records -> call_attempts). A data de referência é o
  # started_at da própria tentativa, em America/Sao_Paulo. Tentativa sem horário legível não
  # entra em nenhuma janela. Duração é só a das chamadas atendidas (a API grava 0 nas não
  # atendidas) e nem todas a informam: toda estatística de duração vem com essa cobertura.
  class AttemptsQuery < Query
    STATUSES = %w[answered not_answered failed].freeze
    RESULTS = %w[confirmed inconclusive rejected not_answered].freeze
    DAILY_KEYS = %i[attempts answered not_answered failed other answer_base with_duration].freeze

    def initialize(batches, window, grouping: Filters::GROUPING_DAY)
      @batches = batches
      @window = window
      @grouping = grouping
      @snapshots = {}
    end

    def summary
      snapshot(@grouping)[:summary]
    end

    # Tentativas e atendimento por hora do dia (0 a 23), no horário de Brasília.
    def by_hour
      snapshot(@grouping)[:by_hour]
    end

    # Tentativas por dia (ou semana), com a mediana de duração de cada período.
    def daily(grouping)
      snapshot(grouping)[:daily]
    end

    # Uma tentativa por linha, para a exportação. Sem telefone discado, transcrição nem gravação.
    def each_row(group_size: 200)
      return enum_for(:each_row, group_size: group_size) unless block_given?

      each_batch_group(@batches, group_size) do |group|
        select_all(row_sql(group)).each do |row|
          yield(
            batch_id: row["batch_id"].to_i,
            workflow_kind: row["workflow_kind"],
            source: row["source"],
            external_id: row["external_id"],
            attempt_number: row["attempt_number"]&.to_i,
            started_at: utc_time(row["started_at"]),
            finished_at: utc_time(row["finished_at"]),
            status: row["status"],
            result: row["result"],
            duration_seconds: decimal(row["duration_seconds"]),
            privacy_refusal_detected: row["privacy_refusal_detected"] == "true"
          )
        end
      end
    end

    private

    # Total, por período e por hora numa única leitura do JSON (GROUPING SETS): expandir as
    # tentativas é a parte cara, então as três visões saem da mesma passada.
    def snapshot(grouping)
      @snapshots[grouping] ||= begin
        rows = select_all(<<~SQL)
          #{attempts_cte}
          SELECT
            GROUPING(bucket) AS without_bucket,
            GROUPING(hour) AS without_hour,
            bucket, hour,
            COUNT(*) AS attempts,
            #{STATUSES.map { |status| "COUNT(*) FILTER (WHERE status = #{quote(status)}) AS #{status}" }.join(",\n  ")},
            COUNT(*) FILTER (WHERE status IS NULL OR status NOT IN (#{Sql.list(STATUSES)})) AS other,
            #{RESULTS.map { |result| "COUNT(*) FILTER (WHERE result = #{quote(result)}) AS result_#{result}" }.join(",\n  ")},
            COUNT(*) FILTER (WHERE result IS NULL OR result NOT IN (#{Sql.list(RESULTS)})) AS result_other,
            COUNT(duration) AS with_duration,
            AVG(duration) AS average_duration,
            percentile_cont(0.5) WITHIN GROUP (ORDER BY duration) AS median_duration
          FROM (
            SELECT attempts.*,
              #{Sql.bucket('started_at', grouping)} AS bucket,
              EXTRACT(HOUR FROM #{Sql.local('started_at')})::int AS hour
            FROM attempts
          ) grouped
          GROUP BY GROUPING SETS ((), (bucket), (hour))
        SQL

        total = rows.find { |row| row["without_bucket"].to_i == 1 && row["without_hour"].to_i == 1 } || {}
        {
          summary: summary_from(total),
          daily: daily_from(rows.select { |row| row["without_bucket"].to_i.zero? }, grouping),
          by_hour: hours_from(rows.select { |row| row["without_hour"].to_i.zero? })
        }
      end
    end

    def summary_from(row)
      {
        attempts: integer(row["attempts"]),
        answered: integer(row["answered"]),
        not_answered: integer(row["not_answered"]),
        failed: integer(row["failed"]),
        other_status: integer(row["other"]),
        answer_base: STATUSES.sum { |status| integer(row[status]) },
        results: RESULTS.to_h { |result| [ result, integer(row["result_#{result}"]) ] }.merge("other" => integer(row["result_other"])),
        with_duration: integer(row["with_duration"]),
        average_duration: decimal(row["average_duration"]),
        median_duration: decimal(row["median_duration"])
      }
    end

    def daily_from(rows, grouping)
      rows = rows.map { |row| row.merge("answer_base" => STATUSES.sum { |status| integer(row[status]) }) }
      medians = rows.to_h { |row| [ row["bucket"].to_date, decimal(row["median_duration"]) ] }
      fill(rows, @window.buckets(grouping), DAILY_KEYS).each { |day| day[:median_duration] = medians[day[:date]] }
    end

    def hours_from(rows)
      indexed = rows.index_by { |row| row["hour"].to_i }
      (0..23).map do |hour|
        row = indexed[hour] || {}
        { hour: hour, attempts: integer(row["attempts"]), answered: integer(row["answered"]), answer_base: STATUSES.sum { |status| integer(row[status]) } }
      end
    end

    def row_sql(group)
      started_at = Sql.timestamp("t.attempt ->> 'started_at'")

      <<~SQL
        SELECT
          si.id AS batch_id, si.workflow_kind, si.source,
          r.record ->> 'external_id' AS external_id,
          #{Sql.number("t.attempt ->> 'attempt_number'")} AS attempt_number,
          #{started_at} AS started_at,
          #{Sql.timestamp("t.attempt ->> 'finished_at'")} AS finished_at,
          t.attempt ->> 'status' AS status,
          t.attempt ->> 'result' AS result,
          COALESCE(#{Sql.number("t.attempt ->> 'duration_seconds'")}, #{Sql.number("t.attempt ->> 'call_duration_seconds'")}) AS duration_seconds,
          t.attempt ->> 'privacy_refusal_detected' AS privacy_refusal_detected
        FROM (#{relation_sql(group, :id, :workflow_kind, :source, :response_payload)}) si
        CROSS JOIN LATERAL jsonb_array_elements(#{Sql.array("si.response_payload -> 'records'")}) WITH ORDINALITY AS r(record, position)
        CROSS JOIN LATERAL jsonb_array_elements(#{Sql.array("r.record -> 'call_attempts'")}) WITH ORDINALITY AS t(attempt, attempt_position)
        WHERE #{started_at} >= #{time_literal(@window.starts_at)} AND #{started_at} < #{time_literal(@window.ends_at)}
        ORDER BY 6, si.id, r.position, t.attempt_position
      SQL
    end

    def attempts_cte
      <<~SQL
        WITH all_attempts AS (
          SELECT
            t.attempt ->> 'status' AS status,
            t.attempt ->> 'result' AS result,
            #{Sql.timestamp("t.attempt ->> 'started_at'")} AS started_at,
            CASE WHEN t.attempt ->> 'status' = 'answered' THEN
              COALESCE(#{Sql.number("t.attempt ->> 'duration_seconds'")}, #{Sql.number("t.attempt ->> 'call_duration_seconds'")})
            END AS duration
          FROM (#{relation_sql(@batches, :id, :response_payload)}) si
          CROSS JOIN LATERAL #{records_of('si')} AS r(record)
          CROSS JOIN LATERAL #{attempts_of('r')} AS t(attempt)
        ),
        attempts AS (
          SELECT * FROM all_attempts
          WHERE started_at >= #{time_literal(@window.starts_at)} AND started_at < #{time_literal(@window.ends_at)}
        )
      SQL
    end
  end
end
