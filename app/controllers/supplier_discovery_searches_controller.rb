class SupplierDiscoverySearchesController < ApplicationController
  include DisplayCodeSearchable
  include PaginatesCollection

  PER_PAGE = 5

  before_action :authenticate_user!
  before_action :set_search, only: [:download_results, :create_segment_import]

  def index
    load_searches
    @search_form_values = default_search_form_values
  end

  def create
    load_searches
    @search_form_values = default_search_form_values.merge(search_params.to_h.symbolize_keys)
    @open_new_search_modal = true

    result = SupplierDiscoverySearches::CreateRemoteSearchService.new(
      user: current_user,
      params: search_params
    ).call

    if result.success?
      redirect_to supplier_discovery_searches_path, notice: I18n.t('supplier_discovery_searches.messages.completed_success')
    else
      Rails.logger.warn("Supplier discovery failed | user_id=#{current_user.id} error=#{result.error_message}")
      flash.now[:alert] = result.error_message
      render :index, status: :unprocessable_entity
    end
  end

  def download_results
    unless @search.download_ready?
      return redirect_to supplier_discovery_searches_path, alert: I18n.t('supplier_discovery_searches.messages.download_unavailable')
    end

    send_data(
      @search.results_xlsx_data,
      filename: @search.download_filename,
      type: @search.download_content_type,
      disposition: 'attachment'
    )
  end

  def create_segment_import
    result = SupplierDiscoverySearches::CreateSupplierImportService.new(
      user: current_user,
      search: @search
    ).call

    if result.success?
      redirect_to supplier_imports_path, notice: I18n.t('supplier_discovery_searches.messages.import_success')
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
      id_search = extract_display_number(params[:q], prefix: 'BS')
      searches = searches.where(
        'id = :id_search OR search_id ILIKE :search OR segment_name ILIKE :search OR COALESCE(region, \'\') ILIKE :search',
        id_search: id_search || -1,
        search:
      )
    end

    pagination = paginate_collection(searches, page_param: params[:page], per_page: PER_PAGE)
    @searches_total_count = pagination[:total_count]
    @searches_total_pages = pagination[:total_pages]
    @searches_page = pagination[:current_page]
    @searches = pagination[:records]
  end

  def search_params
    params.fetch(:supplier_discovery_search, ActionController::Parameters.new).permit(
      :segment_name,
      :region,
      :callback_phone,
      :callback_contact_name,
      :max_suppliers
    )
  end

  def default_search_form_values
    {
      callback_phone: primary_callback_phone,
      callback_contact_name: current_user.validation_owner_name_value,
      max_suppliers: 10
    }
  end

  def primary_callback_phone
    Array(current_user.validation_twilio_phone_numbers).filter_map do |item|
      if item.is_a?(Hash)
        item['phone_number'].presence || item[:phone_number].presence
      else
        item.presence
      end
    end.first
  end

end
