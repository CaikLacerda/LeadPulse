class ValidationAuditsController < ApplicationController
  include PaginatesCollection

  PER_PAGE = 5

  before_action :authenticate_user!
  before_action :require_evidence_access!

  def index
    if current_membership.can_view_evidence?
      PrivacyAudit::Logger.log!(
        account: current_account,
        user: current_user,
        action: "validation_audit_evidence_viewed",
        metadata: { query: params[:q].presence, page: params[:page].presence }
      )
    end

    entries = SupplierImports::AuditEntriesService.call(account: current_account)
    entries = filter_entries(entries)

    pagination = paginate_array(entries, page_param: params[:page], per_page: PER_PAGE)
    @audit_entries = pagination[:records]
    @audit_total_count = pagination[:total_count]
    @audit_total_pages = pagination[:total_pages]
    @audit_page = pagination[:current_page]
  end

  private

  def require_evidence_access!
    return if current_membership.can_view_evidence?

    redirect_to root_path, alert: "Seu perfil não possui permissão para visualizar auditorias."
  end

  def filter_entries(entries)
    return entries if params[:q].blank?

    query = params[:q].to_s.downcase

    entries.select do |entry|
      [
        entry.lot_code,
        entry.supplier_name,
        entry.result_code,
        entry.observation,
        entry.summary,
        entry.customer_transcript,
        entry.assistant_transcript
      ].compact.join(" ").downcase.include?(query)
    end
  end
end
