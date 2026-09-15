class CommercialOpportunitiesController < ApplicationController
  include DisplayCodeSearchable
  include PaginatesCollection

  PER_PAGE = 10

  before_action :authenticate_user!
  before_action :set_commercial_opportunity, only: [ :show, :start, :sync_status, :export ]

  def index
    opportunities = current_user.commercial_opportunities.recent_first
    opportunities = opportunities.where(status: params[:status]) if CommercialOpportunity::STATUSES.include?(params[:status])

    if params[:q].present?
      search = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      id_search = extract_display_number(params[:q], prefix: "RC")
      opportunities = opportunities.where(
        "commercial_opportunities.id = :id OR supplier_name ILIKE :search OR callback_phone ILIKE :search OR source_external_id ILIKE :search",
        id: id_search || -1,
        search: search
      )
    end

    @status_counts = current_user.commercial_opportunities.group(:status).count
    pagination = paginate_collection(opportunities, page_param: params[:page], per_page: PER_PAGE)
    @opportunities = pagination[:records]
    @opportunities_total_count = pagination[:total_count]
    @opportunities_total_pages = pagination[:total_pages]
    @opportunities_page = pagination[:current_page]
  end

  def show; end

  def start
    return redirect_to commercial_opportunities_path, alert: "Seu perfil não possui permissão para iniciar coletas comerciais." unless current_user.can_start_validation?

    CommercialOpportunities::StartRemoteValidationService.new(
      user: current_user,
      commercial_opportunity: @commercial_opportunity
    ).call
    redirect_to commercial_opportunities_path, notice: "Coleta comercial iniciada."
  rescue ValidationApi::Error => e
    # O serviço persiste falhas da tentativa que realmente foi enviada. O
    # controller não deve regredir uma coleta concluída/concorrente por causa de
    # uma requisição manual inválida ou atrasada.
    redirect_to commercial_opportunities_path, alert: e.message
  end

  def sync_status
    unless current_user.can_start_validation?
      return render(json: { error: "forbidden" }, status: :forbidden) if request.format.json?
      return redirect_to commercial_opportunities_path, alert: "Seu perfil não possui permissão para consultar coletas comerciais."
    end

    previous_status = @commercial_opportunity.status
    CommercialOpportunities::SyncRemoteStatusService.new(
      user: current_user,
      commercial_opportunity: @commercial_opportunity
    ).call

    if request.format.json?
      @commercial_opportunity.reload
      return render json: {
        status: @commercial_opportunity.status,
        changed: @commercial_opportunity.status != previous_status,
        terminal: !@commercial_opportunity.processing?
      }
    end

    redirect_to commercial_opportunities_path, notice: "Status comercial atualizado."
  rescue ValidationApi::Error => e
    return render(json: { error: e.message }, status: :bad_gateway) if request.format.json?

    redirect_to commercial_opportunities_path, alert: e.message
  end

  def export
    return redirect_to commercial_opportunity_path(@commercial_opportunity), alert: "Seu perfil não possui permissão para exportar resultados." unless current_user.can_export_data?
    return redirect_to commercial_opportunity_path(@commercial_opportunity), alert: "A coleta comercial ainda não foi concluída." unless @commercial_opportunity.ready_to_export?

    export = CommercialOpportunities::ExportXlsxService.new(
      commercial_opportunity: @commercial_opportunity
    ).call
    send_data export[:content], filename: export[:filename], type: export[:content_type]
  end

  private

  def set_commercial_opportunity
    @commercial_opportunity = current_user.commercial_opportunities.find(params[:id])
  end
end
