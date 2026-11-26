module Analytics
  # Agregados por tentativa de chamada (records -> call_attempts). A data de referência é o
  # started_at da própria tentativa, em America/Sao_Paulo. Tentativa sem horário legível não
  # entra em nenhuma janela. Duração é só a das chamadas atendidas (a API grava 0 nas não
  # atendidas) e nem todas a informam: toda estatística de duração vem com essa cobertura.
  class AttemptsQuery < Query
    STATUSES = %w[answered not_answered failed].freeze
    RESULTS = %w[confirmed inconclusive rejected not_answered].freeze
    DAILY_KEYS = %i[attempts answered not_answered failed other answer_base with_duration].freeze
    # Faixas de leitura operacional para chamadas atendidas. Seguem os intervalos sugeridos
    # pelo produto e cobrem toda duração disponível; o limite superior é sempre exclusivo.
    DURATION_BINS = [
      [ "under_30s", nil, 30 ],
      [ "30s_1m", 30, 60 ],
      [ "1m_2m", 60, 120 ],
      [ "2m_5m", 120, 300 ],
      [ "over_5m", 300, nil ]
    ].freeze

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

    # Tentativas e atendimento por dia da semana (1 = segunda ... 7 = domingo) e hora, no
    # horário de Brasília. Só as combinações com tentativas.
    def weekday_hours
      snapshot(@grouping)[:weekday_hours]
    end

    # Uma tentativa por linha, para a exportação. Sem telefone discado, transcrição nem gravação.
    def each_row(group_size: 200)
      return enum_for(:each_row, group_size: group_size) unless block_given?

      each_batch_group(@batches, group_size) do |group|
        select_all(row_sql(group)).each { |row| yield cast_row(row) }
      end
    end

    # Página de tentativas em ordem estável (início do lote, lote, registro, tentativa), a
    # partir do cursor da página anterior.
    #
    # filter (drill-down): status e result (código ou "outros"), weekday (1 a 7) e hour (0 a
    # 23) no horário de Brasília. Mesmas definições do mapa de calor e dos agregados.
    def page(after: nil, limit: 100, filter: {})
      batches = @batches
      batches = batches.where("(supplier_imports.validation_started_at, supplier_imports.id) >= (?::timestamp, ?)", after[0], after[1]) if after
      rows = select_all(row_sql(batches, after: after, limit: limit + 1, filter: filter)).map { |row| cast_row(row) }
      last = rows[limit - 1]
      next_cursor = ([ last[:batch_started_at].utc.iso8601(6), last[:batch_id], last[:record_position], last[:attempt_position] ] if rows.size > limit)
      [ rows.first(limit), next_cursor ]
    end

    def count(filter: {})
      integer(select_one("SELECT COUNT(*) AS total FROM (#{row_sql(@batches, filter: filter)}) rows")["total"])
    end

    private

    def filter_conditions(filter, started_at)
      conditions = []
      case filter[:status]
      when *STATUSES then conditions << "t.attempt ->> 'status' = #{quote(filter[:status])}"
      when "outros" then conditions << "(t.attempt ->> 'status' IS NULL OR t.attempt ->> 'status' NOT IN (#{Sql.list(STATUSES)}))"
      end
      case filter[:result]
      when *RESULTS then conditions << "t.attempt ->> 'result' = #{quote(filter[:result])}"
      when "outros" then conditions << "(t.attempt ->> 'result' IS NULL OR t.attempt ->> 'result' NOT IN (#{Sql.list(RESULTS)}))"
      end
      conditions << "EXTRACT(ISODOW FROM #{Sql.local(started_at)}) = #{filter[:weekday].to_i}" if filter[:weekday]
      conditions << "EXTRACT(HOUR FROM #{Sql.local(started_at)}) = #{filter[:hour].to_i}" if filter[:hour]
      if filter[:duration]
        _, from, to = DURATION_BINS.find { |key, _, _| key == filter[:duration] }
        duration = "COALESCE(#{Sql.number("t.attempt ->> 'duration_seconds'")}, #{Sql.number("t.attempt ->> 'call_duration_seconds'")})"
        conditions << "t.attempt ->> 'status' = 'answered'"
        conditions << "#{duration} >= #{from}" if from
        conditions << "#{duration} < #{to}" if to
      end
      conditions
    end

    def cast_row(row)
      {
        batch_id: row["batch_id"].to_i,
        workflow_kind: row["workflow_kind"],
        source: row["source"],
        external_id: row["external_id"],
        company_name: row["company_name"],
        attempt_number: row["attempt_number"]&.to_i,
        started_at: utc_time(row["started_at"]),
        finished_at: utc_time(row["finished_at"]),
        status: row["status"],
        result: row["result"],
        duration_seconds: decimal(row["duration_seconds"]),
        privacy_refusal_detected: row["privacy_refusal_detected"] == "true",
        batch_started_at: utc_time(row["batch_started_at"]),
        record_position: row["record_position"].to_i,
        attempt_position: row["attempt_position"].to_i
      }
    end

    # Total, por período e por hora numa única leitura do JSON (GROUPING SETS): expandir as
    # tentativas é a parte cara, então as três visões saem da mesma passada.
    def snapshot(grouping)
      @snapshots[grouping] ||= begin
        rows = select_all(<<~SQL)
          #{attempts_cte}
          SELECT
            GROUPING(bucket) AS without_bucket,
            GROUPING(hour) AS without_hour,
            GROUPING(weekday) AS without_weekday,
            bucket, hour, weekday,
            COUNT(*) AS attempts,
            #{STATUSES.map { |status| "COUNT(*) FILTER (WHERE status = #{quote(status)}) AS #{status}" }.join(",\n  ")},
            COUNT(*) FILTER (WHERE status IS NULL OR status NOT IN (#{Sql.list(STATUSES)})) AS other,
            #{RESULTS.map { |result| "COUNT(*) FILTER (WHERE result = #{quote(result)}) AS result_#{result}" }.join(",\n  ")},
            COUNT(*) FILTER (WHERE result IS NULL OR result NOT IN (#{Sql.list(RESULTS)})) AS result_other,
            COUNT(duration) AS with_duration,
            AVG(duration) AS average_duration,
            percentile_cont(0.5) WITHIN GROUP (ORDER BY duration) AS median_duration,
            percentile_cont(0.9) WITHIN GROUP (ORDER BY duration) AS p90_duration,
            #{duration_bin_columns}
          FROM (
            SELECT attempts.*,
              #{Sql.bucket('started_at', grouping)} AS bucket,
              EXTRACT(HOUR FROM #{Sql.local('started_at')})::int AS hour,
              EXTRACT(ISODOW FROM #{Sql.local('started_at')})::int AS weekday
            FROM attempts
          ) grouped
          GROUP BY GROUPING SETS ((), (bucket), (hour), (weekday, hour))
        SQL

        grouped = ->(bucket, hour, weekday) { rows.select { |row| [ row["without_bucket"].to_i, row["without_hour"].to_i, row["without_weekday"].to_i ] == [ bucket, hour, weekday ] } }
        {
          summary: summary_from(grouped.call(1, 1, 1).first || {}),
          daily: daily_from(grouped.call(0, 1, 1), grouping),
          by_hour: hours_from(grouped.call(1, 0, 1)),
          weekday_hours: grouped.call(1, 0, 0).map do |row|
            { weekday: row["weekday"].to_i, hour: row["hour"].to_i, attempts: integer(row["attempts"]), answered: integer(row["answered"]),
              answer_base: STATUSES.sum { |status| integer(row[status]) } }
          end.sort_by { |cell| [ cell[:weekday], cell[:hour] ] }
        }
      end
    end

    def duration_bin_columns
      DURATION_BINS.map.with_index do |(_, from, to), index|
        conditions = [ ("duration >= #{from}" if from), ("duration < #{to}" if to) ].compact.join(" AND ")
        "COUNT(duration) FILTER (WHERE #{conditions}) AS duration_bin_#{index}"
      end.join(",\n  ")
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
        median_duration: decimal(row["median_duration"]),
        p90_duration: decimal(row["p90_duration"]),
        duration_bins: DURATION_BINS.each_with_index.map { |(key, _, _), index| [ key, integer(row["duration_bin_#{index}"]) ] }
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

    def row_sql(group, after: nil, limit: nil, filter: {})
      started_at = Sql.timestamp("t.attempt ->> 'started_at'")
      conditions = filter_conditions(filter, started_at)
      conditions << "(si.validation_started_at, si.id, r.position, t.attempt_position) > (#{quote(after[0])}::timestamp, #{after[1].to_i}, #{after[2].to_i}, #{after[3].to_i})" if after
      after_sql = conditions.map { |condition| "AND #{condition}" }.join(" ")

      <<~SQL
        SELECT
          si.id AS batch_id, si.workflow_kind, si.source, si.validation_started_at AS batch_started_at,
          r.position AS record_position, t.attempt_position,
          r.record ->> 'external_id' AS external_id,
          COALESCE(NULLIF(r.record ->> 'client_name', ''), r.record ->> 'company_name') AS company_name,
          #{Sql.number("t.attempt ->> 'attempt_number'")} AS attempt_number,
          #{started_at} AS started_at,
          #{Sql.timestamp("t.attempt ->> 'finished_at'")} AS finished_at,
          t.attempt ->> 'status' AS status,
          t.attempt ->> 'result' AS result,
          COALESCE(#{Sql.number("t.attempt ->> 'duration_seconds'")}, #{Sql.number("t.attempt ->> 'call_duration_seconds'")}) AS duration_seconds,
          t.attempt ->> 'privacy_refusal_detected' AS privacy_refusal_detected
        FROM (#{relation_sql(group, :id, :workflow_kind, :source, :validation_started_at, :response_payload)}) si
        CROSS JOIN LATERAL jsonb_array_elements(#{Sql.array("si.response_payload -> 'records'")}) WITH ORDINALITY AS r(record, position)
        CROSS JOIN LATERAL jsonb_array_elements(#{Sql.array("r.record -> 'call_attempts'")}) WITH ORDINALITY AS t(attempt, attempt_position)
        WHERE #{started_at} >= #{time_literal(@window.starts_at)} AND #{started_at} < #{time_literal(@window.ends_at)}
          #{after_sql}
        ORDER BY si.validation_started_at, si.id, r.position, t.attempt_position
        #{"LIMIT #{limit.to_i}" if limit}
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
