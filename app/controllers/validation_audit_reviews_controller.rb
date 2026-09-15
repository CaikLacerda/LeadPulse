class ValidationAuditReviewsController < ApplicationController
  before_action :authenticate_user!

  def create
    return redirect_to validation_audits_path, alert: "Seu perfil não possui permissão para revisar auditorias." unless current_user.can_view_evidence?

    supplier_import = current_user.supplier_imports.find(review_params[:supplier_import_id])
    review = current_user.audit_reviews.find_or_initialize_by(
      supplier_import: supplier_import,
      record_external_id: review_params[:record_external_id].presence,
      provider_call_id: review_params[:provider_call_id].presence,
      attempt_number: review_params[:attempt_number].presence
    )

    review.assign_attributes(
      original_result: review_params[:original_result],
      reviewed_result: review_params[:reviewed_result],
      review_note: review_params[:review_note],
      reviewed_at: Time.current
    )

    if review.save
      PrivacyAudit::Logger.log!(
        user: current_user,
        action: "validation_audit_reviewed",
        supplier_import: supplier_import,
        resource: review,
        metadata: {
          record_external_id: review.record_external_id,
          original_result: review.original_result,
          reviewed_result: review.reviewed_result
        }
      )
      redirect_to validation_audits_path, notice: I18n.t("validation_audits.review.saved")
    else
      redirect_to validation_audits_path, alert: review.errors.full_messages.to_sentence
    end
  end

  private

  def review_params
    params.require(:audit_review).permit(
      :supplier_import_id,
      :record_external_id,
      :provider_call_id,
      :attempt_number,
      :original_result,
      :reviewed_result,
      :review_note
    )
  end
end
