module SupplierImports
  class AnonymizeEvidenceService
    def initialize(account:, supplier_import:)
      @account = account
      @supplier_import = supplier_import
    end

    def call
      ensure_ownership!
      requested_batch_id = @supplier_import.remote_batch_id
      response = anonymize_remote_evidence if @account.validation_api_token_value.present? && @supplier_import.remote_batch_id.present?
      @supplier_import.with_lock do
        raise ValidationApi::Error, "Lote alterado durante a anonimização; consulte o estado atual." if @supplier_import.remote_batch_id != requested_batch_id

        # A resposta da API não traz as tentativas; elas continuam no lote (sem transcrição nem
        # gravação) para que Analytics conte as chamadas feitas.
        source = response.present? ? RemoteEvidenceMerger.new(account: @account, supplier_import: @supplier_import).carry_over(response) : @supplier_import.response_payload
        anonymized_payload = anonymize_payload(source)

        @supplier_import.update!(
          response_payload: anonymized_payload,
          import_metadata: @supplier_import.import_metadata.merge(
            "evidence_anonymized_at" => Time.current.iso8601
          ),
          last_synced_at: Time.current
        )
      end
    end

    private

    def ensure_ownership!
      return if @supplier_import.account_id == @account.id

      raise ActiveRecord::RecordNotFound, "Lote não encontrado para esta conta."
    end

    def anonymize_remote_evidence
      ValidationApi::Validations::AnonymizeEvidenceService.new.call(
        api_token: @account.validation_api_token_value,
        batch_id: @supplier_import.remote_batch_id
      )
    end

    public

    def anonymize_payload(payload)
      sanitized = (payload.presence || {}).deep_dup
      sanitized["privacy_notice"] = (sanitized["privacy_notice"] || {}).merge(
        "evidence_anonymized_at" => sanitized.dig("privacy_notice", "evidence_anonymized_at").presence || @supplier_import.import_metadata["evidence_anonymized_at"].presence || Time.current.iso8601
      )

      sanitized["records"] = Array(sanitized["records"]).map do |record|
        anonymize_record(record)
      end

      sanitized
    end

    private

    def anonymize_record(record)
      sanitized = record.deep_dup
      sanitized["transcript_summary"] = nil
      sanitized["customer_transcript"] = nil
      sanitized["assistant_transcript"] = nil
      sanitized["conversation_turns"] = []
      sanitized["sentiment"] = nil
      sanitized["recording_url"] = nil
      sanitized["recording_sid"] = nil
      sanitized["whatsapp_history"] = []
      sanitized["email_history"] = []
      sanitized["privacy_refusal_reason"] = "Detalhes anonimizados." if sanitized["privacy_refusal_detected"]
      sanitized["evidence_anonymized"] = true
      sanitized["observation"] = "Evidências de áudio/transcrição anonimizadas conforme política LGPD."

      sanitized["call_attempts"] = Array(sanitized["call_attempts"]).map do |attempt|
        anonymize_attempt(attempt)
      end

      sanitized
    end

    def anonymize_attempt(attempt)
      sanitized = attempt.deep_dup
      sanitized["transcript_summary"] = nil
      sanitized["customer_transcript"] = nil
      sanitized["assistant_transcript"] = nil
      sanitized["conversation_turns"] = []
      sanitized["sentiment"] = nil
      sanitized["recording_url"] = nil
      sanitized["recording_sid"] = nil
      sanitized["privacy_refusal_reason"] = "Detalhes anonimizados." if sanitized["privacy_refusal_detected"]
      sanitized["observation"] = "Evidências de áudio/transcrição anonimizadas conforme política LGPD."
      sanitized
    end
  end
end
