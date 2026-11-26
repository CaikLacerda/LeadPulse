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

    # Um registro por linha, para as exportações. Sem telefone, e-mail, transcrição nem gravação.
    def each_row(group_size: 200)
      return enum_for(:each_row, group_size: group_size) unless block_given?

      each_batch_group(@batches, group_size) do |group|
        select_all(row_sql(group)).each { |row| yield cast_row(row) }
      end
    end

    # Página de registros em ordem estável (início do lote, lote, posição no lote), a partir
    # do cursor da página anterior. Devolve as linhas e o cursor da próxima página (ou nil).
    #
    # filter (drill-down): result (código de call_result ou "outros"), call ("com_ligacao" ou
    # "atendidos", pelo call_status) e outcome (resultado da qualificação). Mesmas definições
    # dos agregados, para a lista bater com o número clicado.
    def page(after: nil, limit: 100, filter: {})
      batches = @batches
      batches = batches.where("(supplier_imports.validation_started_at, supplier_imports.id) >= (?::timestamp, ?)", after[0], after[1]) if after
      rows = select_all(row_sql(batches, after: after, limit: limit + 1, filter: filter)).map { |row| cast_row(row) }
      next_cursor = ([ rows[limit - 1][:validation_started_at].utc.iso8601(6), rows[limit - 1][:batch_id], rows[limit - 1][:position] ] if rows.size > limit)
      [ rows.first(limit), next_cursor ]
    end

    def count(filter: {})
      integer(select_one("SELECT COUNT(*) AS total FROM (#{row_sql(@batches, filter: filter)}) rows")["total"])
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

    private

    def row_sql(group, after: nil, limit: nil, filter: {})
      conditions = filter_conditions(filter)
      conditions << "(si.validation_started_at, si.id, r.position) > (#{quote(after[0])}::timestamp, #{after[1].to_i}, #{after[2].to_i})" if after
      after_sql = "WHERE #{conditions.join(' AND ')}" if conditions.any?
      answered_duration = "CASE WHEN t.attempt ->> 'status' = 'answered' THEN #{Sql.number("t.attempt ->> 'duration_seconds'")} END"

      <<~SQL
        SELECT
          si.id AS batch_id, si.workflow_kind, si.source, si.status AS batch_status, si.validation_started_at,
          r.position,
          r.record ->> 'external_id' AS external_id,
          COALESCE(NULLIF(r.record ->> 'client_name', ''), r.record ->> 'company_name') AS company_name,
          COALESCE(NULLIF(r.record ->> 'cnpj_original', ''), r.record ->> 'cnpj_normalized') AS cnpj,
          r.record -> 'supplier_validation' ->> 'segment_name' AS segment_name,
          r.record ->> 'final_status' AS final_status,
          r.record ->> 'call_result' AS call_result,
          r.record ->> 'call_status' AS call_status,
          r.record ->> 'business_status' AS business_status,
          r.record -> 'supplier_validation' ->> 'outcome' AS qualification_outcome,
          r.record -> 'supplier_validation' ->> 'phone_belongs_to_company' AS phone_belongs_to_company,
          r.record -> 'supplier_validation' ->> 'supplies_segment' AS supplies_segment,
          r.record -> 'supplier_validation' ->> 'commercial_interest' AS commercial_interest,
          #{Sql.number("r.record ->> 'attempts_count'")} AS attempts_count,
          (r.record ->> 'privacy_refusal_detected' = 'true'
            OR EXISTS (SELECT 1 FROM #{attempts_of('r')} AS t(attempt) WHERE t.attempt ->> 'privacy_refusal_detected' = 'true')) AS privacy_refusal_detected,
          (SELECT MAX(#{Sql.timestamp("t.attempt ->> 'started_at'")}) FROM #{attempts_of('r')} AS t(attempt)) AS last_attempt_at,
          (SELECT SUM(#{answered_duration}) FROM #{attempts_of('r')} AS t(attempt)) AS answered_duration_seconds
        FROM (#{relation_sql(group, :id, :workflow_kind, :source, :status, :validation_started_at, :response_payload)}) si
        CROSS JOIN LATERAL jsonb_array_elements(#{Sql.array("si.response_payload -> 'records'")}) WITH ORDINALITY AS r(record, position)
        #{after_sql}
        ORDER BY si.validation_started_at, si.id, r.position
        #{"LIMIT #{limit.to_i}" if limit}
      SQL
    end

    def filter_conditions(filter)
      conditions = []
      case filter[:result]
      when *CALL_RESULTS then conditions << "r.record ->> 'call_result' = #{quote(filter[:result])}"
      when "outros" then conditions << "(r.record ->> 'call_result' IS NULL OR r.record ->> 'call_result' NOT IN (#{Sql.list(CALL_RESULTS)}))"
      end
      case filter[:call]
      when "com_ligacao" then conditions << "r.record ->> 'call_status' IN (#{Sql.list(CALLED_STATUSES)})"
      when "atendidos" then conditions << "r.record ->> 'call_status' = 'answered'"
      end
      conditions << "r.record -> 'supplier_validation' ->> 'outcome' = #{quote(filter[:outcome])}" if filter[:outcome].present?
      conditions
    end

    def cast_row(row)
      {
        batch_id: row["batch_id"].to_i,
        position: row["position"].to_i,
        workflow_kind: row["workflow_kind"],
        source: row["source"],
        batch_status: row["batch_status"],
        validation_started_at: utc_time(row["validation_started_at"]),
        external_id: row["external_id"],
        company_name: row["company_name"],
        cnpj: row["cnpj"],
        segment_name: row["segment_name"],
        final_status: row["final_status"],
        call_result: row["call_result"],
        call_status: row["call_status"],
        business_status: row["business_status"],
        qualification_outcome: row["qualification_outcome"],
        phone_belongs_to_company: boolean(row["phone_belongs_to_company"]),
        supplies_segment: boolean(row["supplies_segment"]),
        commercial_interest: boolean(row["commercial_interest"]),
        attempts_count: row["attempts_count"]&.to_i,
        privacy_refusal_detected: ActiveModel::Type::Boolean.new.cast(row["privacy_refusal_detected"]) || false,
        last_attempt_at: utc_time(row["last_attempt_at"]),
        answered_duration_seconds: decimal(row["answered_duration_seconds"])
      }
    end

    def boolean(value)
      return if value.nil?

      value == "true"
    end
  end
end
