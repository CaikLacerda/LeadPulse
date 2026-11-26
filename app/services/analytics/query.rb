module Analytics
  # Base das queries analíticas. Elas recebem relações já escopadas por Analytics::Scope e
  # devolvem só números e códigos, no mesmo formato que uma futura tabela de projeção
  # (validation_records, call_attempts) precisaria devolver.
  class Query
    TERMINAL_RESULTS = %w[confirmed rejected inconclusive not_answered].freeze
    CALL_RESULTS = (TERMINAL_RESULTS + %w[pending_dispatch]).freeze

    private

    def select_one(sql)
      connection.select_one(sql)&.to_h || {}
    end

    def select_all(sql)
      connection.select_all(sql).to_a
    end

    def connection
      ActiveRecord::Base.connection
    end

    # Valores entram sempre citados pelo adapter; nunca por interpolação de texto da URL.
    def quote(value)
      value = value.utc.iso8601(6) if value.respond_to?(:utc)
      connection.quote(value)
    end

    def time_literal(time)
      "#{quote(time)}::timestamptz"
    end

    def relation_sql(relation, *columns)
      relation.reselect(*columns).to_sql
    end

    def records_of(batch_alias)
      "jsonb_array_elements(#{Sql.array("#{batch_alias}.response_payload -> 'records'")})"
    end

    def attempts_of(record_alias)
      "jsonb_array_elements(#{Sql.array("#{record_alias}.record -> 'call_attempts'")})"
    end

    # Percorre os lotes em grupos, na ordem de início da validação, para ler linha a linha
    # sem carregar todos os payloads de uma vez.
    def each_batch_group(relation, size)
      relation.reorder(:validation_started_at, :id).pluck(:id).each_slice(size) do |ids|
        yield relation.unscope(:order).where(id: ids)
      end
    end

    def utc_time(value)
      return if value.blank?
      return value.utc if value.respond_to?(:utc)

      Time.find_zone!("UTC").parse(value.to_s)
    end

    def integer(value)
      value.to_i
    end

    def decimal(value)
      value&.to_f
    end

    # Preenche com zero os dias (ou semanas) sem dado, na ordem da janela.
    def fill(rows, buckets, keys)
      indexed = rows.index_by { |row| row["bucket"].to_date }
      buckets.map do |bucket|
        row = indexed[bucket] || {}
        keys.index_with { |key| row[key.to_s].to_i }.merge(date: bucket)
      end
    end
  end
end
