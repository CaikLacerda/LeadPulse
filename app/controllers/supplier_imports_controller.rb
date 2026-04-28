class SupplierImportsController < ApplicationController
  include DisplayCodeSearchable
  include PaginatesCollection

  PER_PAGE = 5

  before_action :authenticate_user!
  before_action :set_import, only: [:start_validation, :sync_status, :export_result, :destroy]

  def index
    load_imports
    assign_import_modal_state
  end

  def export
    redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.export_from_row')
  end

  def import
    redirect_to supplier_imports_path(open_import_modal: '1')
  end

  def create_import
    if params[:file].blank?
      return redirect_to(
        supplier_imports_path(import_modal_redirect_params),
        alert: I18n.t('supplier_imports.messages.select_file')
      )
    end

    result = SupplierImports::CreateFromUploadService.new(
      user: current_user,
      file: params[:file],
      separator: params[:separator],
      workflow_kind: params[:workflow_kind],
      segment_name: params[:segment_name],
      callback_phone: params[:callback_phone],
      callback_contact_name: params[:callback_contact_name]
    ).call

    if result.success?
      redirect_to supplier_imports_path, notice: I18n.t('supplier_imports.messages.imported_success')
    else
      redirect_to supplier_imports_path(import_modal_redirect_params), alert: result.error_message
    end
  end

  def preview_import
    if params[:file].blank?
      return render json: {
        success: false,
        error_message: I18n.t('supplier_imports.messages.select_file')
      }, status: :unprocessable_entity
    end

    result = SupplierImports::PreviewUploadService.new(
      file: params[:file],
      separator: params[:separator],
      workflow_kind: params[:workflow_kind]
    ).call

    if result.success?
      render json: { success: true, preview: result.preview }
    else
      render json: { success: false, error_message: result.error_message }, status: :unprocessable_entity
    end
  end

  def start_validation
    SupplierImports::StartRemoteValidationService.new(
      user: current_user,
      supplier_import: @import
    ).call

    redirect_to supplier_imports_path, notice: I18n.t('supplier_imports.messages.started_success')
  rescue ValidationApi::Error => e
    redirect_to supplier_imports_path, alert: e.message
  end

  def sync_status
    if @import.remote_batch_id.blank? || @import.validation_started_at.blank?
      return redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.not_started_yet')
    end

    SupplierImports::SyncRemoteStatusService.new(
      user: current_user,
      supplier_import: @import
    ).call

    redirect_to supplier_imports_path, notice: I18n.t('supplier_imports.messages.synced_success')
  rescue ValidationApi::Error => e
    redirect_to supplier_imports_path, alert: e.message
  end

  def export_result
    unless @import.ready_to_export?
      return redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.not_ready_to_export')
    end

    export = SupplierImports::ExportResultCsvService.new(supplier_import: @import).call
    send_data export[:content], filename: export[:filename], type: 'text/csv; charset=utf-8'
  rescue SupplierImports::ExportResultCsvService::Error => e
    redirect_to supplier_imports_path, alert: e.message
  end

  def destroy
    unless @import.destroyable?
      return redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.destroy_not_allowed')
    end

    @import.destroy!
    redirect_to supplier_imports_path, notice: I18n.t('supplier_imports.messages.destroyed_success')
  end

  private

  def load_imports
    imports = current_user.supplier_imports.order(created_at: :desc)

    if params[:status].present? && params[:status] != 'todos'
      imports = imports.where(status: params[:status])
    end

    if params[:workflow_kind].present? && params[:workflow_kind] != 'todos'
      imports = imports.where(workflow_kind: params[:workflow_kind])
    end

    if params[:periodo].present?
      case params[:periodo]
      when '7d'  then imports = imports.where('created_at >= ?', 7.days.ago)
      when '30d' then imports = imports.where('created_at >= ?', 30.days.ago)
      when '1y'  then imports = imports.where('created_at >= ?', 1.year.ago)
      end
    end

    if params[:q].present?
      search = "%#{params[:q]}%"
      id_search = extract_display_number(params[:q], prefix: 'LD')
      imports = imports.where(
        'id::text ILIKE :search OR id = :id_search OR remote_batch_id ILIKE :search OR COALESCE(file_name, \'\') ILIKE :search',
        search: search,
        id_search: id_search || -1
      )
    end

    pagination = paginate_collection(imports, page_param: params[:page], per_page: PER_PAGE)
    @imports_total_count = pagination[:total_count]
    @imports_total_pages = pagination[:total_pages]
    @imports_page = pagination[:current_page]
    @imports = pagination[:records]
  end

  def assign_import_modal_state
    @open_import_modal = ActiveModel::Type::Boolean.new.cast(params[:open_import_modal])
    @import_form_values = {
      workflow_kind: params[:import_workflow_kind].presence || SupplierImport::WORKFLOW_KIND_CADASTRAL
    }
  end

  def import_modal_redirect_params
    {
      open_import_modal: '1',
      import_workflow_kind: params[:workflow_kind]
    }.compact
  end

  def set_import
    @import = current_user.supplier_imports.find(params[:id])
  end
end
