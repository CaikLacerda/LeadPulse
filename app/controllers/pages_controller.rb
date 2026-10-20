class PagesController < ApplicationController
  DAILY_SERIES_DAYS = 30

  def terms; end
  def privacy; end

  def home
    return render("landing/show", layout: "landing") unless current_user

    imports_scope = current_account.supplier_imports
    searches_scope = current_account.supplier_discovery_searches
    recent_imports_scope = imports_scope.order(created_at: :desc)
    status_counts = imports_scope.group(:status).count
    commercial_scope = current_account.commercial_opportunities
    commercial_status_counts = commercial_scope.group(:status).count

    @dashboard_insights = {
      total_batches: imports_scope.count,
      total_searches: searches_scope.count,
      pending_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_PENDING, 0),
      processing_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_PROCESSING, 0),
      completed_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_COMPLETED, 0),
      error_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_ERROR, 0),
      total_records: imports_scope.sum(:total_rows),
      ready_exports: imports_scope.where(result_ready: true).count,
      commercial_total: commercial_scope.count,
      commercial_pending: commercial_status_counts.fetch(CommercialOpportunity::STATUS_PENDING, 0),
      commercial_processing: commercial_status_counts.fetch(CommercialOpportunity::STATUS_PROCESSING, 0)
    }
    @daily_imports = daily_import_series(imports_scope)
    @recent_imports = recent_imports_scope.limit(5)
    @recent_searches = searches_scope.recent_first.limit(5)
    @recent_location_searches = searches_scope.recent_first.limit(12)
    @welcome_account_name = current_account.validation_company_name_value
    @welcome_contact_name = current_user.name
    @integration_flags = {
      company: current_account.validation_account_id.present?,
      twilio: current_account.validation_twilio_configured?,
      openai: current_account.validation_openai_configured?,
      api_token: current_account.validation_api_token_configured?
    }
  end

  private

  # Registros e lotes importados por dia no fuso do workspace, para o gráfico do dashboard.
  def daily_import_series(imports_scope)
    time_zone = ActiveSupport::TimeZone[ApplicationHelper::WORKSPACE_TIME_ZONE]
    today = Time.current.in_time_zone(time_zone).to_date
    first_day = today - (DAILY_SERIES_DAYS - 1)

    imports_by_day = imports_scope
      .where(created_at: first_day.in_time_zone(time_zone).beginning_of_day..)
      .pluck(:created_at, :total_rows)
      .group_by { |created_at, _total_rows| created_at.in_time_zone(time_zone).to_date }

    (first_day..today).map do |date|
      entries = imports_by_day.fetch(date, [])
      { date:, batches: entries.size, records: entries.sum { |_created_at, total_rows| total_rows.to_i } }
    end
  end
end
