class PrivacyAuditEventsController < ApplicationController
  include PaginatesCollection

  before_action :authenticate_user!
  require_permission :can_manage_lgpd?, message: "Seu perfil não possui permissão para consultar auditoria LGPD."

  def index
    scope = current_account.privacy_audit_events.includes(:supplier_import, :performed_by).order(occurred_at: :desc)
    pagination = paginate_collection(scope, page_param: params[:page], per_page: 25)
    @events = pagination[:records]
    @events_page = pagination[:current_page]
    @events_total_pages = pagination[:total_pages]
    @events_total_count = pagination[:total_count]
  end
end
