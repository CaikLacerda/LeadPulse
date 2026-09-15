class SupplierDiscoverySearchesController < ApplicationController
  include DisplayCodeSearchable
  include PaginatesCollection

  PER_PAGE = 5

  before_action :authenticate_user!
  before_action :set_search, only: [ :download_results, :create_segment_import, :retry_search ]

  def index
    load_searches
    @search_form_values = default_search_form_values
  end

  def create
    return redirect_to supplier_discovery_searches_path, alert: "Seu perfil não possui permissão para buscar fornecedores." unless current_user.can_import_data?

    load_searches
    @search_form_values = default_search_form_values.merge(search_params.to_h.symbolize_keys)
    @open_new_search_modal = true

    result = SupplierDiscoverySearches::QueueRemoteSearchService.new(
      user: current_user,
      params: search_params
    ).call

    if result.success?
      redirect_to supplier_discovery_searches_path, notice: I18n.t("supplier_discovery_searches.messages.queued_success")
    else
      Rails.logger.warn("Supplier discovery failed | user_id=#{current_user.id} error=#{result.error_message}")
      flash.now[:alert] = result.error_message
      render :index, status: :unprocessable_entity
    end
  end

  def progress
    active_searches = current_user.supplier_discovery_searches.active.order(:id)
    render json: {
      active: active_searches.exists?,
      fingerprint: progress_fingerprint(active_searches)
    }
  end

  def retry_search
    return redirect_to supplier_discovery_searches_path, alert: "Seu perfil não possui permissão para buscar fornecedores." unless current_user.can_import_data?
    return redirect_to supplier_discovery_searches_path, alert: I18n.t("supplier_discovery_searches.messages.retry_unavailable") unless @search.errored?

    @search.update!(
      status: SupplierDiscoverySearch::LOCAL_STATUS_PENDING,
      error_message: nil
    )
    SupplierDiscoverySearchJob.perform_later(@search)
    redirect_to supplier_discovery_searches_path, notice: I18n.t("supplier_discovery_searches.messages.retry_queued")
  rescue ActiveJob::EnqueueError
    @search.update(status: SupplierDiscoverySearch::LOCAL_STATUS_ERROR)
    redirect_to supplier_discovery_searches_path, alert: I18n.t("supplier_discovery_searches.messages.queue_error")
  end

  def download_results
    return redirect_to supplier_discovery_searches_path, alert: "Seu perfil não possui permissão para baixar resultados." unless current_user.can_export_data?

    unless @search.download_ready?
      return redirect_to supplier_discovery_searches_path, alert: I18n.t("supplier_discovery_searches.messages.download_unavailable")
    end

    PrivacyAudit::Logger.log!(
      user: current_user,
      action: "supplier_discovery_downloaded",
      resource: @search,
      metadata: { search_id: @search.search_id, filename: @search.download_filename }
    )

    send_data(
      @search.results_xlsx_data,
      filename: @search.download_filename,
      type: @search.download_content_type,
      disposition: "attachment"
    )
  end

  def create_segment_import
    return redirect_to supplier_discovery_searches_path, alert: "Seu perfil não possui permissão para importar fornecedores." unless current_user.can_import_data?

    result = SupplierDiscoverySearches::CreateSupplierImportService.new(
      user: current_user,
      search: @search
    ).call

    if result.success?
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: "supplier_discovery_import_created",
        supplier_import: result.import,
        resource: @search,
        metadata: { search_id: @search.search_id, supplier_import_id: result.import.id }
      )
      redirect_to supplier_imports_path, notice: I18n.t("supplier_discovery_searches.messages.import_success")
    else
      redirect_to supplier_discovery_searches_path, alert: result.error_message
    end
  end

  private

  def set_search
    @search = current_user.supplier_discovery_searches.find(params[:id])
  end

  def load_searches
    searches = current_user.supplier_discovery_searches.recent_first

    if params[:q].present?
      search = "%#{params[:q]}%"
      id_search = extract_display_number(params[:q], prefix: "BS")
      searches = searches.where(
        "id = :id_search OR search_id ILIKE :search OR segment_name ILIKE :search OR COALESCE(region, '') ILIKE :search",
        id_search: id_search || -1,
        search:
      )
    end

    pagination = paginate_collection(searches, page_param: params[:page], per_page: PER_PAGE)
    @searches_total_count = pagination[:total_count]
    @searches_total_pages = pagination[:total_pages]
    @searches_page = pagination[:current_page]
    @searches = pagination[:records]
    @active_search_fingerprint = progress_fingerprint(
      current_user.supplier_discovery_searches.active.order(:id)
    )
  end

  def search_params
    params.fetch(:supplier_discovery_search, ActionController::Parameters.new).permit(
      :segment_name,
      :region,
      :max_suppliers
    )
  end

  def default_search_form_values
    { max_suppliers: 10 }
  end

  def progress_fingerprint(searches)
    searches.map { |search| "#{search.id}:#{search.status}:#{search.updated_at.to_f}" }.join("|")
  end
end
