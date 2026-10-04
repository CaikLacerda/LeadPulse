module Maintenance
  # Recupera as evidências de lotes sincronizados depois que a API passou a separá-las do
  # resultado (31/08/2026). Esses lotes já terminaram, então a sincronização periódica não
  # passa mais por eles. Só considera lotes cujo response_payload tem o formato separado e
  # ainda não recebeu evidências. Sem apply, apenas lista.
  class RemoteEvidenceBackfill
    Row = Data.define(:supplier_import, :result, :error, :records_changed)

    def initialize(account: nil, apply: false, preview: false)
      raise ArgumentError, "Preview e apply são mutuamente exclusivos" if apply && preview
      @account = account
      @apply = apply
      @preview = preview
    end

    def call
      candidates.map { |supplier_import| backfill(supplier_import) }
    end

    private

    def candidates
      scope = SupplierImport.includes(:account).where.not(remote_batch_id: [ nil, "" ]).where.not(validation_started_at: nil)
      scope = scope.where(account: @account) if @account
      scope.order(:id).select { |supplier_import| missing_evidence?(supplier_import.response_payload) }
    end

    def missing_evidence?(payload)
      records = payload.is_a?(Hash) ? payload["records"] : nil
      records.is_a?(Array) && records.any? && payload[SupplierImports::RemoteEvidenceMerger::SYNCED_AT_KEY].blank? &&
        records.all? { |record| record.is_a?(Hash) && record.key?("attempts_count") && !record.key?("call_attempts") }
    end

    def backfill(supplier_import)
      return Row.new(supplier_import: supplier_import, result: :pending, error: nil, records_changed: 0) unless @apply || @preview

      original_payload = supplier_import.response_payload.deep_dup
      original_batch_id = supplier_import.remote_batch_id
      merged = SupplierImports::RemoteEvidenceMerger.new(account: supplier_import.account, supplier_import: supplier_import)
        .call(supplier_import.response_payload, batch_id: supplier_import.remote_batch_id)
      if merged[SupplierImports::RemoteEvidenceMerger::SYNCED_AT_KEY].blank?
        return Row.new(supplier_import: supplier_import, result: :failed, error: "API não devolveu as evidências", records_changed: 0)
      end

      previous = supplier_import.response_payload.fetch("records").index_by { |record| record["external_id"].to_s }
      records_changed = merged.fetch("records").count { |record| record != previous[record["external_id"].to_s] }
      if @apply
        supplier_import.with_lock do
          if supplier_import.remote_batch_id != original_batch_id || supplier_import.response_payload != original_payload || supplier_import.evidence_anonymized?
            return Row.new(supplier_import: supplier_import, result: :failed, error: "Lote alterado durante a busca; refaça o preview", records_changed: 0)
          end
          supplier_import.update!(response_payload: merged)
        end
      end
      Row.new(supplier_import: supplier_import, result: @apply ? :applied : :would_apply, error: nil, records_changed: records_changed)
    end
  end
end
