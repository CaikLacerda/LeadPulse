module Analytics
  # Agregados por tentativa de chamada (records -> call_attempts). A data de referência é o
  # started_at da própria tentativa, em America/Sao_Paulo. Tentativa sem horário legível não
  # entra em nenhuma janela. Duração é só a das chamadas atendidas (a API grava 0 nas não
  # atendidas) e nem todas a informam: toda estatística de duração vem com essa cobertura.
  class AttemptsQuery < Query
    STATUSES = %w[answered not_answered failed].freeze
    RESULTS = %w[confirmed inconclusive rejected not_answered].freeze
    DAILY_KEYS = %i[attempts answered not_answered failed other answer_base with_duration].freeze

    def initialize(batches, window)
      @batches = batches
      @window = window
    end

    def summary
      row = select_one(<<~SQL)
        #{attempts_cte}
        SELECT
          COUNT(*) AS attempts,
          #{STATUSES.map { |status| "COUNT(*) FILTER (WHERE status = #{quote(status)}) AS #{status}" }.join(",\n  ")},
          COUNT(*) FILTER (WHERE status IS NULL OR status NOT IN (#{Sql.list(STATUSES)})) AS other_status,
          #{RESULTS.map { |result| "COUNT(*) FILTER (WHERE result = #{quote(result)}) AS result_#{result}" }.join(",\n  ")},
          COUNT(*) FILTER (WHERE result IS NULL OR result NOT IN (#{Sql.list(RESULTS)})) AS result_other,
          COUNT(duration) AS with_duration,
          AVG(duration) AS average_duration,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY duration) AS median_duration
        FROM attempts
      SQL

      {
        attempts: integer(row["attempts"]),
        answered: integer(row["answered"]),
        not_answered: integer(row["not_answered"]),
        failed: integer(row["failed"]),
        other_status: integer(row["other_status"]),
        answer_base: STATUSES.sum { |status| integer(row[status]) },
        results: RESULTS.to_h { |result| [ result, integer(row["result_#{result}"]) ] }.merge("other" => integer(row["result_other"])),
        with_duration: integer(row["with_duration"]),
        average_duration: decimal(row["average_duration"]),
        median_duration: decimal(row["median_duration"])
      }
    end

    # Tentativas e atendimento por hora do dia (0 a 23), no horário de Brasília.
    def by_hour
      rows = select_all(<<~SQL).index_by { |row| row["hour"].to_i }
        #{attempts_cte}
        SELECT EXTRACT(HOUR FROM #{Sql.local('started_at')})::int AS hour,
          COUNT(*) AS attempts,
          COUNT(*) FILTER (WHERE status = 'answered') AS answered,
          COUNT(*) FILTER (WHERE status IN (#{Sql.list(STATUSES)})) AS answer_base
        FROM attempts
        GROUP BY 1
      SQL

      (0..23).map do |hour|
        row = rows[hour] || {}
        { hour: hour, attempts: row["attempts"].to_i, answered: row["answered"].to_i, answer_base: row["answer_base"].to_i }
      end
    end

    # Tentativas por dia (ou semana), com a mediana de duração de cada período.
    def daily(grouping)
      rows = select_all(<<~SQL)
        #{attempts_cte}
        SELECT #{Sql.bucket('started_at', grouping)} AS bucket,
          COUNT(*) AS attempts,
          #{STATUSES.map { |status| "COUNT(*) FILTER (WHERE status = #{quote(status)}) AS #{status}" }.join(",\n  ")},
          COUNT(*) FILTER (WHERE status IS NULL OR status NOT IN (#{Sql.list(STATUSES)})) AS other,
          COUNT(*) FILTER (WHERE status IN (#{Sql.list(STATUSES)})) AS answer_base,
          COUNT(duration) AS with_duration,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY duration) AS median_duration
        FROM attempts
        GROUP BY 1
      SQL

      medians = rows.to_h { |row| [ row["bucket"].to_date, decimal(row["median_duration"]) ] }
      fill(rows, @window.buckets(grouping), DAILY_KEYS).each { |day| day[:median_duration] = medians[day[:date]] }
    end

    private

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
