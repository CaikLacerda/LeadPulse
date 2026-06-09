module SupplierImports
  class AnonymizeEvidenceService
    def initialize(user:, supplier_import:)
      @user = user
      @supplier_import = supplier_import
    end

    def call
      response = anonymize_remote_evidence if @user.validation_api_token_value.present? && @supplier_import.remote_batch_id.present?
      anonymized_payload = anonymize_payload(response.presence || @supplier_import.response_payload)

      @supplier_import.update!(
        response_payload: anonymized_payload,
        import_metadata: @supplier_import.import_metadata.merge(
          'evidence_anonymized_at' => Time.current.iso8601
        ),
        last_synced_at: Time.current
      )
    end

    private

    def anonymize_remote_evidence
      ValidationApi::Validations::AnonymizeEvidenceService.new.call(
        api_token: @user.validation_api_token_value,
        batch_id: @supplier_import.remote_batch_id
      )
    end

    def anonymize_payload(payload)
      sanitized = (payload.presence || {}).deep_dup
      sanitized['privacy_notice'] = (sanitized['privacy_notice'] || {}).merge(
        'evidence_anonymized_at' => Time.current.iso8601
      )

      sanitized['records'] = Array(sanitized['records']).map do |record|
        anonymize_record(record)
      end

      sanitized
    end

    def anonymize_record(record)
      sanitized = record.deep_dup
      sanitized['transcript_summary'] = nil
      sanitized['customer_transcript'] = nil
      sanitized['assistant_transcript'] = nil
      sanitized['sentiment'] = nil
      sanitized['privacy_refusal_reason'] = 'Detalhes anonimizados.' if sanitized['privacy_refusal_detected']
      sanitized['evidence_anonymized'] = true

      sanitized['call_attempts'] = Array(sanitized['call_attempts']).map do |attempt|
        anonymize_attempt(attempt)
      end

      sanitized
    end

    def anonymize_attempt(attempt)
      sanitized = attempt.deep_dup
      sanitized['transcript_summary'] = nil
      sanitized['customer_transcript'] = nil
      sanitized['assistant_transcript'] = nil
      sanitized['sentiment'] = nil
      sanitized['recording_url'] = nil
      sanitized['recording_sid'] = nil
      sanitized['privacy_refusal_reason'] = 'Detalhes anonimizados.' if sanitized['privacy_refusal_detected']
      sanitized['observation'] = 'Evidências de áudio/transcrição anonimizadas conforme política LGPD.'
      sanitized
    end
  end
end
