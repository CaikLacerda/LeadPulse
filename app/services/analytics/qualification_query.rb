module Analytics
  # Resultados do fluxo Segmento, funil comercial, buscas e revisões humanas. Todas as
  # relações chegam prontas de Analytics::Scope.
  #
  # Uma revisão conta como "alterada" quando o resultado revisado não coincide com nenhuma
  # classificação automática do registro (call_result, business_status, final_status ou
  # outcome). A comparação direta com original_result não serve: a revisão usa o vocabulário
  # de negócio e o original guarda o código da chamada.
  class QualificationQuery < Query
    QUALIFIED = "qualified_supplier".freeze

    def initialize(batches:, opportunities:, searches:, discovery_batches:, reviews:, review_batches:)
      @batches = batches.where(workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER)
      @opportunities = opportunities
      @searches = searches
      @discovery_batches = discovery_batches
      @reviews = reviews
      @review_batches = review_batches
    end

    # Registros do fluxo Segmento por resultado da qualificação, no total e por origem do lote.
    def outcomes
      rows = select_all(<<~SQL)
        SELECT si.source, r.record -> 'supplier_validation' ->> 'outcome' AS outcome, COUNT(*) AS total
        FROM (#{relation_sql(@batches, :id, :source, :response_payload)}) si
        CROSS JOIN LATERAL #{records_of('si')} AS r(record)
        GROUP BY 1, 2
      SQL

      by_outcome = Hash.new(0)
      by_source = Hash.new { |hash, key| hash[key] = { records: 0, with_outcome: 0, qualified: 0 } }
      rows.each do |row|
        total = row["total"].to_i
        by_outcome[row["outcome"]] += total if row["outcome"].present?
        source = by_source[row["source"]]
        source[:records] += total
        source[:with_outcome] += total if row["outcome"].present?
        source[:qualified] += total if row["outcome"] == QUALIFIED
      end

      {
        records: by_source.values.sum { |source| source[:records] },
        with_outcome: by_outcome.values.sum,
        qualified: by_outcome[QUALIFIED],
        by_outcome: by_outcome.sort_by { |_, total| -total }.to_h,
        by_source: by_source.to_h
      }
    end

    # Retornos comerciais dos mesmos lotes. O funil conta só os que vêm de um registro que está
    # qualificado no payload atual, para cada etapa caber na anterior; os demais ficam em
    # outside_funnel e aparecem numa nota.
    def funnel
      completed = quote(CommercialOpportunity::STATUS_COMPLETED)
      row = select_one(<<~SQL)
        SELECT
          COUNT(*) AS opportunities,
          COUNT(*) FILTER (WHERE co.status = #{completed}) AS collected,
          COUNT(*) FILTER (WHERE qualified.found) AS funnel_opportunities,
          COUNT(*) FILTER (WHERE qualified.found AND co.status = #{completed}) AS funnel_collected
        FROM (#{relation_sql(@opportunities, :id, :status, :supplier_import_id, :source_external_id)}) co
        LEFT JOIN LATERAL (
          SELECT TRUE AS found
          FROM (#{relation_sql(@batches, :id, :response_payload)}) si
          CROSS JOIN LATERAL #{records_of('si')} AS r(record)
          WHERE si.id = co.supplier_import_id
            AND r.record ->> 'external_id' = co.source_external_id
            AND r.record -> 'supplier_validation' ->> 'outcome' = #{quote(QUALIFIED)}
          LIMIT 1
        ) qualified ON TRUE
      SQL

      opportunities = integer(row["opportunities"])
      funnel_opportunities = integer(row["funnel_opportunities"])
      {
        opportunities: opportunities,
        collected: integer(row["collected"]),
        funnel_opportunities: funnel_opportunities,
        funnel_collected: integer(row["funnel_collected"]),
        outside_funnel: opportunities - funnel_opportunities
      }
    end

    # Buscas do período por segmento, com quantas viraram lote.
    def searches
      rows = select_all(<<~SQL)
        SELECT
          COALESCE(NULLIF(TRIM(s.segment_name), ''), '—') AS segment,
          COUNT(*) AS searches,
          COALESCE(SUM(s.total_suppliers), 0) AS found,
          COUNT(*) FILTER (WHERE EXISTS (
            SELECT 1 FROM (#{relation_sql(@discovery_batches, :id, :import_metadata)}) b
            WHERE b.import_metadata ->> 'supplier_discovery_search_id' = s.id::text
          )) AS converted,
          COALESCE(SUM((
            SELECT COUNT(*) FROM (#{relation_sql(@discovery_batches, :id, :import_metadata)}) b
            WHERE b.import_metadata ->> 'supplier_discovery_search_id' = s.id::text
          )), 0) AS batches
        FROM (#{relation_sql(@searches, :id, :segment_name, :total_suppliers)}) s
        GROUP BY 1
        ORDER BY searches DESC, segment
      SQL

      segments = rows.map do |row|
        { segment: row["segment"], searches: integer(row["searches"]), found: integer(row["found"]), converted: integer(row["converted"]), batches: integer(row["batches"]) }
      end

      {
        searches: segments.sum { |segment| segment[:searches] },
        found: segments.sum { |segment| segment[:found] },
        converted: segments.sum { |segment| segment[:converted] },
        segments: segments
      }
    end

    def reviews
      row = select_one(<<~SQL)
        SELECT
          COUNT(*) AS reviews,
          COUNT(*) FILTER (WHERE rec.record IS NULL) AS unmatched,
          COUNT(*) FILTER (
            WHERE rec.record IS NOT NULL
              AND NOT COALESCE(ar.reviewed_result = ANY (ARRAY[
                rec.record ->> 'call_result',
                rec.record ->> 'business_status',
                rec.record ->> 'final_status',
                rec.record -> 'supplier_validation' ->> 'outcome'
              ]), false)
          ) AS altered
        FROM (#{relation_sql(@reviews, :id, :supplier_import_id, :record_external_id, :reviewed_result)}) ar
        JOIN (#{relation_sql(@review_batches, :id, :response_payload)}) si ON si.id = ar.supplier_import_id
        LEFT JOIN LATERAL (
          SELECT r.record FROM #{records_of('si')} AS r(record)
          WHERE r.record ->> 'external_id' = ar.record_external_id
          LIMIT 1
        ) rec ON TRUE
      SQL

      { reviews: integer(row["reviews"]), altered: integer(row["altered"]), unmatched: integer(row["unmatched"]) }
    end
  end
end
