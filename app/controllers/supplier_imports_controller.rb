class SupplierImportsController < ApplicationController
  include DisplayCodeSearchable
  include PaginatesCollection

  PER_PAGE = 5

  before_action :authenticate_user!
  before_action :set_import, only: [:show, :start_validation, :sync_status, :anonymize_evidence, :export_result, :privacy_report, :destroy]

  def index
    load_imports
    assign_import_modal_state
  end

  def show
    if current_user.can_view_evidence?
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: 'supplier_import_evidence_viewed',
        supplier_import: @import,
        resource: @import,
        metadata: { page: 'supplier_import_show' }
      )
    end
  end

  def export
    redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.export_from_row')
  end

  def import
    redirect_to supplier_imports_path(open_import_modal: '1')
  end

  def create_import
    return redirect_to supplier_imports_path, alert: 'Seu perfil não possui permissão para importar bases.' unless current_user.can_import_data?

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
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: 'supplier_import_created',
        supplier_import: result.import,
        resource: result.import,
        metadata: {
          file_name: result.import.file_name,
          total_rows: result.import.total_rows,
          legal_basis: result.import.request_payload.dig('privacy_notice', 'legal_basis') || result.import.request_payload.dig(:privacy_notice, :legal_basis)
        }
      )
      redirect_to supplier_imports_path, notice: I18n.t('supplier_imports.messages.imported_success')
    else
      redirect_to supplier_imports_path(import_modal_redirect_params), alert: result.error_message
    end
  end

  def preview_import
    return render json: { success: false, error_message: 'Seu perfil não possui permissão para importar bases.' }, status: :forbidden unless current_user.can_import_data?

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

  def academic_report
    return redirect_to supplier_imports_path, alert: 'Seu perfil não possui permissão para exportar relatórios.' unless current_user.can_export_data?

    export = SupplierImports::AcademicReportService.new(imports: current_user.supplier_imports.order(created_at: :desc)).call
    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'academic_report_exported',
      metadata: { format: 'csv', imports_count: current_user.supplier_imports.count }
    )
    send_data export[:content], filename: export[:filename], type: export[:content_type]
  end

  def start_validation
    return redirect_to supplier_imports_path, alert: 'Seu perfil não possui permissão para iniciar validações.' unless current_user.can_start_validation?

    SupplierImports::StartRemoteValidationService.new(
      user: current_user,
      supplier_import: @import
    ).call

    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'supplier_import_validation_started',
      supplier_import: @import,
      resource: @import,
      metadata: { remote_batch_id: @import.remote_batch_id }
    )
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

  def anonymize_evidence
    return redirect_to supplier_import_path(@import), alert: 'Seu perfil não possui permissão para anonimizar evidências.' unless current_user.can_anonymize_evidence?

    SupplierImports::AnonymizeEvidenceService.new(
      user: current_user,
      supplier_import: @import
    ).call

    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'supplier_import_evidence_anonymized',
      supplier_import: @import,
      resource: @import,
      metadata: { remote_batch_id: @import.remote_batch_id }
    )
    redirect_to supplier_import_path(@import), notice: I18n.t('supplier_imports.messages.evidence_anonymized')
  rescue ValidationApi::Error => e
    redirect_to supplier_import_path(@import), alert: e.message
  end

  def export_result
    return redirect_to supplier_imports_path, alert: 'Seu perfil não possui permissão para exportar resultados.' unless current_user.can_export_data?

    unless @import.ready_to_export?
      return redirect_to supplier_imports_path, alert: I18n.t('supplier_imports.messages.not_ready_to_export')
    end

    export =
      if params[:format].to_s == 'xlsx'
        SupplierImports::ExportResultXlsxService.new(supplier_import: @import).call
      else
        SupplierImports::ExportResultCsvService.new(supplier_import: @import).call
      end

    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'supplier_import_result_exported',
      supplier_import: @import,
      resource: @import,
      metadata: { filename: export[:filename], format: params[:format].presence || 'csv' }
    )
    send_data export[:content], filename: export[:filename], type: export[:content_type]
  rescue SupplierImports::ExportResultCsvService::Error, SupplierImports::ExportResultXlsxService::Error => e
    redirect_to supplier_imports_path, alert: e.message
  end

  def privacy_report
    return redirect_to supplier_import_path(@import), alert: 'Seu perfil não possui permissão para exportar relatórios LGPD.' unless current_user.can_export_data?

    export = SupplierImports::PrivacyReportService.new(supplier_import: @import).call
    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'supplier_import_privacy_report_exported',
      supplier_import: @import,
      resource: @import,
      metadata: { filename: export[:filename] }
    )
    send_data export[:content], filename: export[:filename], type: export[:content_type]
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
