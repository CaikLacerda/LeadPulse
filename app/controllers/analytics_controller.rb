# Indicadores agregados da conta atual. Todos os papéis veem os agregados; os dados vêm
# sempre de Analytics::Scope, a partir de current_account.
class AnalyticsController < ApplicationController
  DRILL_PAGE_SIZE = 25
  RECORD_DRILL = {
    "resultado" => [ :result, Analytics::Query::CALL_RESULTS + [ "outros" ] ],
    "ligacao" => [ :call, %w[com_ligacao atendidos] ],
    "qualificacao" => [ :outcome, /\A[a-z_]{1,40}\z/ ]
  }.freeze
  ATTEMPT_DRILL = {
    "status" => [ :status, Analytics::AttemptsQuery::STATUSES + [ "outros" ] ],
    "resultado" => [ :result, Analytics::AttemptsQuery::RESULTS + [ "outros" ] ],
    "dia_semana" => [ :weekday, (1..7).map(&:to_s) ],
    "hora" => [ :hour, (0..23).map(&:to_s) ],
    "duracao" => [ :duration, Analytics::AttemptsQuery::DURATION_BINS.map(&:first) ]
  }.freeze

  before_action :authenticate_user!
  # Drill-down mostra registros (fornecedor, resultado): mesma regra do detalhe do lote.
  require_permission :can_view_evidence?, only: %i[records attempts], fallback: :analytics_path,
    message: "Seu perfil não pode abrir os registros do Analytics."
  before_action :load_report

  def overview
    @page = @report.overview
  end

  def calls
    @page = @report.calls
  end

  def qualification
    @page = @report.qualification
  end

  def batches
    @page = @report.batches
  end

  # Registros que compõem um número do Analytics (mesmo período, filtros e definições).
  def records
    @drill = drill_filter(RECORD_DRILL)
    query = Analytics::RecordsQuery.new(@scope.validated_batches(@filters.window))
    @total = query.count(filter: @drill[:filter])
    @rows, @next_cursor = query.page(after: drill_cursor(3), limit: DRILL_PAGE_SIZE, filter: @drill[:filter])
  end

  # Tentativas de chamada que compõem um número do Analytics.
  def attempts
    @drill = drill_filter(ATTEMPT_DRILL)
    query = Analytics::AttemptsQuery.new(@scope.attempt_batches(@filters.window), @filters.window)
    @total = query.count(filter: @drill[:filter])
    @rows, @next_cursor = query.page(after: drill_cursor(4), limit: DRILL_PAGE_SIZE, filter: @drill[:filter])
  end

  # XLSX para todos os papéis (agregados; a aba Registros só com can_export_data?).
  # CSV é dado por registro: exige can_export_data?. Toda exportação entra na trilha LGPD.
  def export
    params[:format] == "csv" ? export_csv : export_xlsx
  end

  private

  # Só valores da lista permitida entram no filtro; o resto é ignorado.
  def drill_filter(definitions)
    params_used = {}
    filter = {}
    definitions.each do |name, (key, allowed)|
      value = params[name].to_s
      next if value.empty?
      next unless allowed.is_a?(Regexp) ? value.match?(allowed) : allowed.include?(value)

      params_used[name] = value
      filter[key] = value
    end
    { filter: filter, params: params_used }
  end

  def drill_cursor(parts)
    raw = params[:pagina].to_s
    return if raw.empty?

    values = JSON.parse(Base64.urlsafe_decode64(raw))
    values if values.is_a?(Array) && values.size == parts && values.first.is_a?(String) && values.drop(1).all?(Integer)
  rescue ArgumentError, JSON::ParserError
    nil
  end

  def export_xlsx
    export = Analytics::XlsxExport.new(
      report: @report,
      scope: @scope,
      user: current_user,
      include_records: current_membership.can_export_data?
    ).call

    log_export(export: "xlsx", filename: export[:filename], sheets: export[:sheets], records_included: current_membership.can_export_data?)
    send_data export[:content], filename: export[:filename], type: export[:content_type]
  rescue Analytics::XlsxExport::TooManyRecords
    redirect_to analytics_path(@filters.to_params), alert: t("analytics.export.too_many_records")
  end

  def export_csv
    return redirect_to analytics_path(@filters.to_params), alert: t("analytics.export.forbidden") unless current_membership.can_export_data?

    dataset = Analytics::CsvExport::DATASETS.include?(params[:conjunto]) ? params[:conjunto] : "registros"
    export = Analytics::CsvExport.new(scope: @scope, dataset: dataset)
    log_export(export: "csv_#{dataset}", filename: export.filename, dataset: dataset)

    response.headers["Content-Type"] = Analytics::CsvExport::CONTENT_TYPE
    response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: export.filename)
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers.delete("Content-Length")
    self.response_body = export.each
  end

  # A empresa é dona do dado; o usuário é o autor da exportação. O horário é o occurred_at.
  def log_export(export:, filename:, **details)
    PrivacyAudit::Logger.log!(
      account: current_account,
      user: current_user,
      action: "analytics_exported",
      metadata: { export: export, filename: filename, filters: @filters.to_params, period: @filters.window.label, **details }
    )
  end

  def load_report
    @filters = Analytics::Filters.new(params, account: current_account)
    @scope = Analytics::Scope.new(account: current_account, filters: @filters)
    @report = Analytics::Report.new(scope: @scope)
    @last_synced_at = current_account.supplier_imports.maximum(:last_synced_at)
  end
end
