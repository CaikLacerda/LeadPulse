# Indicadores agregados da conta atual. Todos os papéis veem os agregados; os dados vêm
# sempre de Analytics::Scope, a partir de current_account.
class AnalyticsController < ApplicationController
  before_action :authenticate_user!
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

  # XLSX para todos os papéis (agregados; a aba Registros só com can_export_data?).
  # CSV é dado por registro: exige can_export_data?. Toda exportação entra na trilha LGPD.
  def export
    params[:format] == "csv" ? export_csv : export_xlsx
  end

  private

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
  end
end
