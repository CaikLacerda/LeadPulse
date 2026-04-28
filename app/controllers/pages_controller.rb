class PagesController < ApplicationController
  def home
    return unless current_user

    imports_scope = current_user.supplier_imports
    searches_scope = current_user.supplier_discovery_searches
    recent_imports_scope = imports_scope.order(created_at: :desc)
    status_counts = imports_scope.group(:status).count

    @dashboard_insights = {
      total_batches: imports_scope.count,
      total_searches: searches_scope.count,
      pending_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_PENDING, 0),
      processing_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_PROCESSING, 0),
      completed_batches: status_counts.fetch(SupplierImport::LOCAL_STATUS_COMPLETED, 0),
      total_records: imports_scope.sum(:total_rows),
      ready_exports: imports_scope.where(result_ready: true).count
    }
    @recent_imports = recent_imports_scope.limit(5)
    @recent_searches = searches_scope.recent_first.limit(5)
    @welcome_account_name = current_user.validation_company_name_value
    @welcome_contact_name = current_user.validation_owner_name_value
    @integration_flags = {
      company: current_user.validation_account_id.present?,
      twilio: current_user.validation_twilio_account_sid.present? && current_user.validation_twilio_auth_token.present? && current_user.validation_twilio_phone_numbers.present?,
      openai: current_user.validation_openai_api_key.present?,
      api_token: current_user.validation_api_token_configured?
    }
  end
end
