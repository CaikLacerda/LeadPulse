module SupplierImports
  # O polling da API de validação devolve o resultado sem as evidências (tentativas de
  # chamada, turnos, gravação e validade das evidências); elas ficam em
  # GET /validations/:batch_id/evidence. Analytics, auditoria, relatório LGPD, exportações e
  # retenção leem as evidências do response_payload, então a sincronização busca e mescla
  # as evidências no resultado, registro a registro (pelo external_id).
  #
  # A busca só acontece quando o resultado vem nesse formato (registros com attempts_count e
  # sem call_attempts) e houve progresso ou passaram 15 minutos. Sem busca, ou
  # se ela falhar, as evidências já gravadas são mantidas.
  class RemoteEvidenceMerger
    PAGE_SIZE = 200
    MAX_PAGES = 1_000
    REFRESH_INTERVAL = 15.minutes
    RECORD_EVIDENCE_KEYS = %w[call_attempts privacy_refusal_detected privacy_refusal_reason evidence_anonymized whatsapp_history email_history].freeze
    PROGRESS_KEYS = %w[external_id final_status business_status call_status call_result attempts_count].freeze
    NOTICE_EVIDENCE_KEYS = %w[evidence_expires_at evidence_anonymized_at].freeze
    SYNCED_AT_KEY = "evidence_synced_at".freeze

    def initialize(account:, supplier_import:, evidence_service: ValidationApi::Validations::ShowEvidenceService.new)
      @account = account
      @supplier_import = supplier_import
      @evidence_service = evidence_service
    end

    def call(response, batch_id:)
      raise ActiveRecord::RecordNotFound unless @supplier_import.account_id == @account.id
      if response.is_a?(Hash) && response["batch_id"].present? && response["batch_id"] != batch_id
        raise ValidationApi::Error, "Identificador de lote divergente"
      end
      return carry_over(response) if @supplier_import.evidence_anonymized?
      return carry_over(response) unless evidence_split?(response)
      return carry_over(response) unless refresh_needed?(response)

      begin
        evidence_records, notice = fetch_evidence(batch_id)
        merge(response, evidence_records, notice)
      rescue ValidationApi::Error => e
        Rails.logger.warn("Evidências do lote #{@supplier_import.id} não sincronizadas: #{e.class.name}")
        carry_over(response)
      end
    end

    # Resultado novo com as evidências já gravadas no lote (sem chamar a API).
    def carry_over(response)
      return response unless response.is_a?(Hash)

      merged = response.deep_dup
      previous_records = records_by_external_id(previous_payload["records"])
      merged["records"] = Array(merged.fetch("records", previous_payload["records"])).map do |record|
        evidence = previous_records[record["external_id"].to_s]
        next record unless evidence

        combined = record.merge(evidence.slice(*RECORD_EVIDENCE_KEYS).reject { |key, _| record.key?(key) })
        combined["call_attempts"] = merge_attempts(evidence["call_attempts"], record["call_attempts"]) if evidence.key?("call_attempts")
        combined
      end
      merged["privacy_notice"] = previous_payload["privacy_notice"].to_h.merge(merged["privacy_notice"].to_h) if previous_payload["privacy_notice"].present?
      merged[SYNCED_AT_KEY] ||= previous_payload[SYNCED_AT_KEY] if previous_payload[SYNCED_AT_KEY].present?
      sanitize(merged)
    end

    private

    def evidence_split?(response)
      records = response.is_a?(Hash) ? response["records"] : nil
      records.is_a?(Array) && records.any? &&
        records.any? { |record| record.is_a?(Hash) && record.key?("attempts_count") && !record.key?("call_attempts") }
    end

    def refresh_needed?(response)
      synced_at = ValidationApi::Timestamp.parse(previous_payload[SYNCED_AT_KEY])
      synced_at.nil? || synced_at <= REFRESH_INTERVAL.ago || progress_signature(response) != progress_signature(previous_payload)
    end

    def progress_signature(payload)
      [ payload["batch_status"], Array(payload["records"]).map { |record| record.to_h.slice(*PROGRESS_KEYS) } ]
    end

    def fetch_evidence(batch_id)
      records = []
      notice = {}
      MAX_PAGES.times do |page|
        evidence = @evidence_service.call(
          api_token: @account.validation_api_token_value,
          batch_id: batch_id,
          limit: PAGE_SIZE,
          offset: page * PAGE_SIZE
        )
        unless evidence.is_a?(Hash) && evidence["records"].is_a?(Array) &&
            (evidence["batch_id"].blank? || evidence["batch_id"] == batch_id)
          raise ValidationApi::Error, "Resposta de evidências inválida"
        end
        records.concat(evidence["records"])
        notice = evidence.slice(*NOTICE_EVIDENCE_KEYS)
        return [ records, notice ] unless evidence["has_more"] == true
      end

      raise ValidationApi::Error, "Paginação de evidências excedeu o limite seguro"
    end

    def merge(response, evidence_records, notice)
      merged = carry_over(response)
      fresh = records_by_external_id(evidence_records)
      merged["records"] = merged["records"].map do |record|
        evidence = fresh[record["external_id"].to_s]
        next record unless evidence

        combined = record.merge(evidence.slice(*RECORD_EVIDENCE_KEYS))
        combined["call_attempts"] = merge_attempts(record["call_attempts"], evidence["call_attempts"])
        combined
      end
      merged["privacy_notice"] = @supplier_import.privacy_notice.merge(merged["privacy_notice"].to_h).merge(notice.compact)
      merged[SYNCED_AT_KEY] = Time.current.iso8601
      sanitize(merged)
    end

    # attempt_number is stable within a record; never join across records or batches.
    def merge_attempts(previous, fresh)
      (Array(previous) + Array(fresh)).each_with_object({}) do |attempt, merged|
        next unless attempt.is_a?(Hash)

        key = attempt["attempt_number"].presence || attempt["provider_call_id"].presence || attempt
        merged[key] = (merged[key] || {}).merge(attempt.reject { |_, value| value.nil? })
      end.values
    end

    def sanitize(payload)
      return payload unless payload.is_a?(Hash)

      anonymizer = AnonymizeEvidenceService.new(account: @account, supplier_import: @supplier_import)
      if @supplier_import.evidence_anonymized? || payload.dig("privacy_notice", "evidence_anonymized_at").present?
        anonymizer.anonymize_payload(payload)
      else
        previous = records_by_external_id(previous_payload["records"])
        payload["records"] = Array(payload["records"]).map do |record|
          if record["evidence_anonymized"] || previous[record["external_id"].to_s]&.fetch("evidence_anonymized", false)
            anonymizer.anonymize_payload({ "records" => [ record ] })["records"].first
          else
            record
          end
        end
        payload
      end
    end

    def records_by_external_id(records)
      Array(records).each_with_object({}) do |record, by_id|
        by_id[record["external_id"].to_s] = record if record.is_a?(Hash) && record["external_id"].present?
      end
    end

    def previous_payload
      @previous_payload ||= begin
        stored = @supplier_import.response_payload.is_a?(Hash) ? @supplier_import.response_payload : {}
        # A replacement can be claimed before its creation response arrives. Keep the old
        # payload available for recovery, but never attach its attempts to the new batch.
        stored["batch_id"].present? && stored["batch_id"] != @supplier_import.remote_batch_id ? {} : stored
      end
    end
  end
end
