# Monta lotes com registros e tentativas controlados para os testes do Analytics, no mesmo
# formato do response_payload da API de validação, sem depender dela.
module AnalyticsPayloadBuilder
  RECORD_DEFAULTS = {
    "confirmed" => { "final_status" => "validated", "call_status" => "answered", "outcome" => "qualified_supplier" },
    "rejected" => { "final_status" => "validation_failed", "call_status" => "answered", "outcome" => "does_not_supply_segment" },
    "inconclusive" => { "final_status" => "validation_failed", "call_status" => "answered", "outcome" => "inconclusive" },
    "not_answered" => { "final_status" => "validation_failed", "call_status" => "not_answered", "outcome" => "not_answered" },
    "pending_dispatch" => { "final_status" => "processing", "call_status" => "queued", "outcome" => nil }
  }.freeze

  def create_analytics_batch!(account:, started_at:, records: [], user: nil, created_at: nil, payload: {}, **attributes)
    user ||= account.users.first || create_member!(name: "Analytics", email: "analytics-#{SecureRandom.hex(4)}@example.test", account: account)
    account.supplier_imports.create!(
      {
        user: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: records.size,
        valid_rows: records.size,
        invalid_rows: 0,
        created_at: created_at || started_at,
        validation_started_at: started_at,
        response_payload: { "records" => records }.merge(payload)
      }.merge(attributes)
    )
  end

  def analytics_record(call_result, attempts: [], **overrides)
    defaults = RECORD_DEFAULTS.fetch(call_result, {})
    record = {
      "external_id" => "rec-#{SecureRandom.hex(4)}",
      "client_name" => "Fornecedor",
      "phone_normalized" => "+5511900000000",
      "call_result" => call_result,
      "final_status" => defaults["final_status"],
      "call_status" => defaults["call_status"],
      "attempts_count" => [ attempts.size, 1 ].max,
      "privacy_refusal_detected" => false,
      "call_attempts" => attempts
    }
    record["supplier_validation"] = { "outcome" => defaults["outcome"] } if defaults["outcome"]
    record.merge(overrides.stringify_keys)
  end

  def analytics_records(counts)
    counts.flat_map { |call_result, total| Array.new(total) { analytics_record(call_result.to_s) } }
  end

  # started_at no formato da API: UTC sem sufixo de fuso.
  def analytics_attempt(status, started_at:, duration: nil, result: nil, **overrides)
    {
      "attempt_number" => 1,
      "status" => status,
      "result" => result || (status == "answered" ? "confirmed" : status),
      "started_at" => started_at.utc.strftime("%Y-%m-%dT%H:%M:%S.%6N"),
      "duration_seconds" => duration,
      "customer_transcript" => "texto",
      "recording_url" => "https://example.test/gravacao"
    }.merge(overrides.stringify_keys)
  end

  def analytics_filters(account, today: Date.new(2026, 9, 25), **params)
    Analytics::Filters.new(params, account: account, today: today)
  end

  def analytics_scope(account, **filter_params)
    filters = analytics_filters(account, **filter_params)
    Analytics::Scope.new(account: account, filters: filters)
  end

  # Horário de Brasília, como a pessoa lê na tela.
  def brasilia(*parts)
    ActiveSupport::TimeZone["America/Sao_Paulo"].local(*parts)
  end
end
