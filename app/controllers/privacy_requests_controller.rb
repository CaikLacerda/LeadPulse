class PrivacyRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lgpd_manager!
  before_action :set_privacy_request, only: :update

  def index
    @privacy_requests = current_user.privacy_requests.includes(:supplier_import).order(created_at: :desc)
    @privacy_request = current_user.privacy_requests.new(requested_at: Time.current)
  end

  def create
    @privacy_request = current_user.privacy_requests.new(privacy_request_params.merge(requested_at: Time.current))

    if @privacy_request.save
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: 'privacy_request_created',
        supplier_import: @privacy_request.supplier_import,
        resource: @privacy_request,
        metadata: {
          request_type: @privacy_request.request_type,
          subject_contact: @privacy_request.subject_contact
        }
      )
      redirect_to privacy_requests_path, notice: 'Solicitação LGPD registrada.'
    else
      @privacy_requests = current_user.privacy_requests.includes(:supplier_import).order(created_at: :desc)
      flash.now[:alert] = @privacy_request.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @privacy_request.update(privacy_request_update_params.merge(resolved_at: resolved_at_value))
      apply_request_effect!
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: 'privacy_request_updated',
        supplier_import: @privacy_request.supplier_import,
        resource: @privacy_request,
        metadata: {
          status: @privacy_request.status,
          request_type: @privacy_request.request_type
        }
      )
      redirect_to privacy_requests_path, notice: 'Solicitação LGPD atualizada.'
    else
      @privacy_requests = current_user.privacy_requests.includes(:supplier_import).order(created_at: :desc)
      flash.now[:alert] = @privacy_request.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  private

  def require_lgpd_manager!
    return if current_user.can_manage_lgpd?

    redirect_to root_path, alert: 'Seu perfil não possui permissão para gerenciar LGPD.'
  end

  def set_privacy_request
    @privacy_request = current_user.privacy_requests.find(params[:id])
  end

  def privacy_request_params
    params.require(:privacy_request).permit(
      :supplier_import_id,
      :request_type,
      :subject_name,
      :subject_contact,
      :supplier_name,
      :phone,
      :description
    )
  end

  def privacy_request_update_params
    params.require(:privacy_request).permit(:status, :resolution)
  end

  def resolved_at_value
    %w[resolved rejected].include?(privacy_request_update_params[:status]) ? Time.current : nil
  end

  def apply_request_effect!
    return unless @privacy_request.status == 'resolved'
    return unless %w[anonymization deletion].include?(@privacy_request.request_type)
    return if @privacy_request.supplier_import.blank?

    SupplierImports::AnonymizeEvidenceService.new(
      user: current_user,
      supplier_import: @privacy_request.supplier_import
    ).call

    PrivacyAudit::Logger.log!(
      user: current_user,
      action: 'privacy_request_evidence_anonymized',
      supplier_import: @privacy_request.supplier_import,
      resource: @privacy_request,
      metadata: { request_type: @privacy_request.request_type }
    )
  end
end
