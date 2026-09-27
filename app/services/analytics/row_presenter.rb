module Analytics
  # Contrato estável das linhas do Analytics, compartilhado pelo CSV e pela API de BI:
  # nomes em inglês, códigos da API de validação, datas ISO 8601 em UTC e durações em
  # segundos inteiros. Nunca inclui telefone, e-mail, transcrição nem gravação.
  module RowPresenter
    RECORD_FIELDS = %w[
      batch_id batch_code workflow_kind source batch_status validation_started_at record_external_id
      company_name cnpj segment_name final_status call_result call_status business_status
      qualification_outcome phone_belongs_to_company supplies_segment commercial_interest
      attempts_count privacy_refusal_detected last_attempt_at answered_duration_seconds
    ].freeze

    ATTEMPT_FIELDS = %w[
      batch_id batch_code workflow_kind source record_external_id attempt_number started_at finished_at
      status result duration_seconds privacy_refusal_detected
    ].freeze

    BATCH_FIELDS = %w[
      batch_id batch_code workflow_kind source status created_at validation_started_at total_rows invalid_rows
      records validated confirmed terminal_results not_answered confirmation_rate wait_seconds processing_seconds
    ].freeze

    module_function

    def record(row)
      {
        "batch_id" => row[:batch_id],
        "batch_code" => SupplierImport.display_code_for(row[:batch_id]),
        "workflow_kind" => row[:workflow_kind],
        "source" => row[:source],
        "batch_status" => row[:batch_status],
        "validation_started_at" => time(row[:validation_started_at]),
        "record_external_id" => row[:external_id],
        "company_name" => row[:company_name],
        "cnpj" => row[:cnpj],
        "segment_name" => row[:segment_name],
        "final_status" => row[:final_status],
        "call_result" => row[:call_result],
        "call_status" => row[:call_status],
        "business_status" => row[:business_status],
        "qualification_outcome" => row[:qualification_outcome],
        "phone_belongs_to_company" => row[:phone_belongs_to_company],
        "supplies_segment" => row[:supplies_segment],
        "commercial_interest" => row[:commercial_interest],
        "attempts_count" => row[:attempts_count],
        "privacy_refusal_detected" => row[:privacy_refusal_detected],
        "last_attempt_at" => time(row[:last_attempt_at]),
        "answered_duration_seconds" => seconds(row[:answered_duration_seconds])
      }
    end

    def attempt(row)
      {
        "batch_id" => row[:batch_id],
        "batch_code" => SupplierImport.display_code_for(row[:batch_id]),
        "workflow_kind" => row[:workflow_kind],
        "source" => row[:source],
        "record_external_id" => row[:external_id],
        "attempt_number" => row[:attempt_number],
        "started_at" => time(row[:started_at]),
        "finished_at" => time(row[:finished_at]),
        "status" => row[:status],
        "result" => row[:result],
        "duration_seconds" => seconds(row[:duration_seconds]),
        "privacy_refusal_detected" => row[:privacy_refusal_detected]
      }
    end

    def batch(row)
      {
        "batch_id" => row[:id],
        "batch_code" => SupplierImport.display_code_for(row[:id]),
        "workflow_kind" => row[:workflow_kind],
        "source" => row[:source],
        "status" => row[:status],
        "created_at" => time(row[:created_at]),
        "validation_started_at" => time(row[:validation_started_at]),
        "total_rows" => row[:total_rows],
        "invalid_rows" => row[:invalid_rows],
        "records" => row[:records],
        "validated" => row[:validated],
        "confirmed" => row[:confirmed],
        "terminal_results" => row[:terminal],
        "not_answered" => row[:not_answered],
        "confirmation_rate" => (row[:terminal].positive? ? (row[:confirmed].to_f / row[:terminal]).round(4) : nil),
        "wait_seconds" => seconds(row[:wait_seconds]),
        "processing_seconds" => seconds(row[:processing_seconds])
      }
    end

    def time(value)
      value&.utc&.iso8601
    end

    def seconds(value)
      value&.round
    end
  end
end
