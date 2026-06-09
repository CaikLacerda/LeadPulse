require 'csv'

module SupplierImports
  class PrivacyReportService
    def initialize(supplier_import:)
      @supplier_import = supplier_import
    end

    def call
      {
        content: build_csv,
        filename: "lote-#{@supplier_import.display_number}-lgpd.csv",
        content_type: 'text/csv; charset=utf-8'
      }
    end

    private

    def build_csv
      CSV.generate(headers: true) do |csv|
        csv << ['Campo', 'Valor']
        rows.each { |label, value| csv << [label, value] }
      end
    end

    def rows
      notice = @supplier_import.privacy_notice
      [
        ['Lote', @supplier_import.display_code],
        ['Usuário responsável', @supplier_import.user.email],
        ['Data da importação', @supplier_import.created_at&.iso8601],
        ['Finalidade declarada', notice['purpose']],
        ['Base legal informada', notice['legal_basis']],
        ['Aviso falado', notice['notice_script']],
        ['Retenção em dias', notice['evidence_retention_days']],
        ['Expiração das evidências', notice['evidence_expires_at']],
        ['Gravação permitida', notice['recording_allowed']],
        ['Registros importados', @supplier_import.total_rows],
        ['Registros válidos', @supplier_import.valid_rows],
        ['Registros inválidos', @supplier_import.invalid_rows],
        ['Chamadas/tentativas registradas', attempts.size],
        ['Gravações vinculadas', attempts.count { |attempt| attempt['recording_url'].present? }],
        ['Transcrições/resumos gerados', transcript_count],
        ['Recusas/interrupções LGPD', privacy_refusal_count],
        ['Evidências anonimizadas', @supplier_import.evidence_anonymized?],
        ['Anonimizado em', @supplier_import.import_metadata['evidence_anonymized_at'] || notice['evidence_anonymized_at']],
        ['Integrações utilizadas', integrations_used]
      ]
    end

    def records
      Array(@supplier_import.response_payload['records'])
    end

    def attempts
      records.flat_map { |record| Array(record['call_attempts']) }
    end

    def transcript_count
      records.count { |record| record['transcript_summary'].present? || record['customer_transcript'].present? || record['assistant_transcript'].present? } +
        attempts.count { |attempt| attempt['transcript_summary'].present? || attempt['customer_transcript'].present? || attempt['assistant_transcript'].present? }
    end

    def privacy_refusal_count
      records.count do |record|
        record['privacy_refusal_detected'].present? ||
          Array(record['call_attempts']).any? { |attempt| attempt['privacy_refusal_detected'].present? }
      end
    end

    def integrations_used
      ['LeadPulse Web', 'LeadPulse API', 'Twilio', 'OpenAI', 'Google Maps'].join(' | ')
    end
  end
end
