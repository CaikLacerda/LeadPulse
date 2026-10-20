module Analytics
  # Único ponto de entrada dos dados do Analytics. Toda relação nasce do account_id da conta
  # atual e dos filtros validados; as queries recebem essas relações e nunca montam escopo.
  class Scope
    # Colunas lidas pelas queries. Nunca SELECT * em supplier_imports: a tabela guarda planilhas.
    BATCH_COLUMNS = %i[
      id workflow_kind source status total_rows valid_rows invalid_rows
      created_at validation_started_at finished_at response_payload
    ].freeze
    # Diferença tolerada entre o relógio local e o da API ao buscar tentativas de uma janela.
    CLOCK_SKEW_MARGIN = 1.hour
    # Folga para tentativas registradas depois da conclusão do lote (nos dados reais, até 4 min).
    FINISHED_MARGIN = 1.day
    BATCH_OPTIONS_LIMIT = 200

    attr_reader :account, :filters

    def initialize(account:, filters:)
      raise ArgumentError, "Analytics exige uma conta salva" unless account&.persisted?

      @account = account
      @filters = filters
    end

    # Lotes cujos registros contam na janela. Referência: início da validação.
    def validated_batches(window)
      batches.where(validation_started_at: window.range)
    end

    # Lotes que podem ter tentativas na janela: iniciados antes do fim dela e não concluídos
    # antes do início (com folga). O recorte fino é pelo horário de cada tentativa.
    def attempt_batches(window)
      batches
        .where(validation_started_at: ...(window.ends_at + CLOCK_SKEW_MARGIN))
        .where("supplier_imports.finished_at IS NULL OR supplier_imports.finished_at >= ?", window.starts_at - FINISHED_MARGIN)
    end

    # Lotes criados na janela (página Lotes), com o filtro de status local.
    def created_batches(window)
      relation = batches.where(created_at: window.range)
      relation = relation.where(status: filters.status) if filters.status
      relation
    end

    def commercial_opportunities_for(batch_relation)
      CommercialOpportunity.where(account_id: account.id, supplier_import_id: batch_relation.reselect(:id))
    end

    # Buscas não têm fluxo, origem nem lote: só o período se aplica.
    def discovery_searches(window)
      SupplierDiscoverySearch.where(account_id: account.id, created_at: window.range)
    end

    # Lotes da conta vindos de busca, sem os demais filtros, para medir a conversão das buscas.
    def discovery_batches
      SupplierImport.where(account_id: account.id, source: SupplierImport::SOURCE_SUPPLIER_DISCOVERY)
    end

    # Revisões feitas na janela (referência: reviewed_at), de lotes que passam nos filtros.
    def audit_reviews(window)
      AuditReview.where(account_id: account.id, reviewed_at: window.range, supplier_import_id: batches.reselect(:id))
    end

    # Lotes da conta com os filtros, sem período: para ligar revisões aos seus registros.
    def review_batches
      batches
    end

    def batch_options
      SupplierImport.where(account_id: account.id).order(created_at: :desc).limit(BATCH_OPTIONS_LIMIT).pluck(:id)
    end

    # Versão dos dados de cada fonte: muda quando um registro é criado, alterado ou removido.
    def source_version(models)
      models.map do |model|
        count, updated_at = model.where(account_id: account.id).pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(updated_at)"))
        updated_at = updated_at.utc.iso8601(6) if updated_at.respond_to?(:utc)
        "#{model.table_name}:#{count}:#{updated_at}"
      end.join("|")
    end

    private

    def batches
      relation = SupplierImport.where(account_id: account.id).select(*BATCH_COLUMNS)
      relation = relation.where(workflow_kind: filters.workflow_kind) if filters.workflow_kind
      relation = relation.where(source: filters.source) if filters.source
      relation = relation.where(id: filters.supplier_import_id) if filters.supplier_import_id
      relation
    end
  end
end
