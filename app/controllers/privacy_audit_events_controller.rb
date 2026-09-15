class PrivacyAuditEventsController < ApplicationController
  include PaginatesCollection

  before_action :authenticate_user!
  before_action :require_lgpd_manager!

  def index
    scope = current_user.privacy_audit_events.includes(:supplier_import).order(occurred_at: :desc)
    pagination = paginate_collection(scope, page_param: params[:page], per_page: 25)
    @events = pagination[:records]
    @events_page = pagination[:current_page]
    @events_total_pages = pagination[:total_pages]
    @events_total_count = pagination[:total_count]
  end

  private

  def require_lgpd_manager!
    return if current_user.can_manage_lgpd?

    redirect_to root_path, alert: "Seu perfil não possui permissão para consultar auditoria LGPD."
  end
end
