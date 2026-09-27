class PlatformSettingsController < ApplicationController
  before_action :authenticate_user!
  require_permission :can_manage_settings?, message: "Seu perfil não possui permissão para alterar configurações."

  def company; end
  def twilio; end
  def openai; end
  def api_token; end
  def lgpd; end

  def update_lgpd
    unless current_membership.can_manage_lgpd?
      return redirect_to lgpd_platform_settings_path, alert: "Seu perfil não possui permissão para alterar LGPD."
    end

    current_account.update!(lgpd_params)
    PrivacyAudit::Logger.log!(
      account: current_account,
      user: current_user,
      action: "lgpd_settings_updated",
      metadata: {
        legal_basis: current_account.lgpd_legal_basis,
        purpose: current_account.lgpd_purpose,
        retention_days: current_account.lgpd_evidence_retention_days,
        recording_allowed: current_account.lgpd_recording_allowed
      }
    )
    redirect_to lgpd_platform_settings_path, notice: "Política LGPD atualizada."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :lgpd, status: :unprocessable_entity
  end

  def update_company
    if (missing_fields = missing_required_fields(company_params, {
      validation_company_name: "Nome da empresa",
      validation_spoken_company_name: "Nome falado pela IA",
      validation_owner_name: "Responsável",
      validation_owner_email: "E-mail do responsável"
    })).any?
      flash.now[:alert] = "Preencha os campos obrigatórios: #{missing_fields.join(', ')}."
      return render :company, status: :unprocessable_entity
    end

    current_account.assign_attributes(company_params)
    return render_invalid_settings(:company) unless current_account.valid?

    response =
      if current_account.validation_account_id.present?
        ValidationApi::PlatformAccounts::UpdateCompanyProfileService.new.call(
          account_id: current_account.validation_account_id,
          company_name: company_params[:validation_company_name],
          spoken_company_name: company_params[:validation_spoken_company_name],
          owner_name: company_params[:validation_owner_name],
          owner_email: company_params[:validation_owner_email],
          calling_profile: company_params[:validation_calling_profile]
        )
      else
        ValidationApi::PlatformAccounts::CreateService.new.call(
          external_account_id: current_account.validation_external_account_reference,
          company_name: company_params[:validation_company_name],
          spoken_company_name: company_params[:validation_spoken_company_name],
          owner_name: company_params[:validation_owner_name],
          owner_email: company_params[:validation_owner_email],
          calling_profile: company_params[:validation_calling_profile]
        )
      end

    persist_account_snapshot!(response)
    current_account.update!(company_params)
    redirect_to company_platform_settings_path, notice: "Dados da empresa sincronizados com a API."
  rescue ValidationApi::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :company, status: :unprocessable_entity
  end

  def update_twilio
    if (missing_fields = missing_required_fields(twilio_params, {
      validation_twilio_account_sid: "Account SID",
      validation_twilio_auth_token: "Auth Token",
      validation_twilio_webhook_base_url: "Webhook base URL",
      validation_twilio_phone_numbers_text: "Números Twilio ativos"
    })).any?
      flash.now[:alert] = "Preencha os campos obrigatórios: #{missing_fields.join(', ')}."
      return render :twilio, status: :unprocessable_entity
    end

    phone_numbers = build_twilio_phone_numbers
    if phone_numbers.empty?
      flash.now[:alert] = "Informe pelo menos um número Twilio ativo."
      return render :twilio, status: :unprocessable_entity
    end

    current_account.assign_attributes(
      validation_twilio_account_sid: twilio_params[:validation_twilio_account_sid],
      validation_twilio_webhook_base_url: twilio_params[:validation_twilio_webhook_base_url],
      validation_twilio_phone_numbers: phone_numbers
    )
    return render_invalid_settings(:twilio) unless current_account.valid?

    ensure_remote_account!

    response = ValidationApi::PlatformAccounts::UpdateTwilioProviderService.new.call(
      account_id: current_account.validation_account_id,
      account_sid: twilio_params[:validation_twilio_account_sid],
      auth_token: twilio_params[:validation_twilio_auth_token],
      webhook_base_url: twilio_params[:validation_twilio_webhook_base_url],
      phone_numbers: phone_numbers
    )

    persist_account_snapshot!(response)
    current_account.update!(
      validation_twilio_account_sid: twilio_params[:validation_twilio_account_sid],
      validation_twilio_webhook_base_url: twilio_params[:validation_twilio_webhook_base_url],
      validation_twilio_phone_numbers: phone_numbers
    )

    redirect_to twilio_platform_settings_path, notice: "Configuração da Twilio atualizada."
  rescue ValidationApi::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :twilio, status: :unprocessable_entity
  end

  def update_openai
    if (missing_fields = missing_required_fields(openai_params, {
      validation_openai_api_key: "API Key",
      validation_openai_realtime_model: "Modelo",
      validation_openai_realtime_voice: "Voz",
      validation_openai_realtime_output_speed: "Velocidade"
    })).any?
      flash.now[:alert] = "Preencha os campos obrigatórios: #{missing_fields.join(', ')}."
      return render :openai, status: :unprocessable_entity
    end

    local_openai_params = openai_params.except(:validation_openai_api_key)
    current_account.assign_attributes(local_openai_params)
    return render_invalid_settings(:openai) unless current_account.valid?

    ensure_remote_account!

    response = ValidationApi::PlatformAccounts::UpdateOpenaiProviderService.new.call(
      account_id: current_account.validation_account_id,
      api_key: openai_params[:validation_openai_api_key],
      realtime_model: openai_params[:validation_openai_realtime_model],
      realtime_voice: openai_params[:validation_openai_realtime_voice],
      realtime_output_speed: openai_params[:validation_openai_realtime_output_speed],
      realtime_style_instructions: openai_params[:validation_openai_style_instructions]
    )

    persist_account_snapshot!(response)
    current_account.update!(local_openai_params)
    redirect_to openai_platform_settings_path, notice: "Configuração da OpenAI atualizada."
  rescue ValidationApi::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :openai, status: :unprocessable_entity
  end

  def create_api_token
    ensure_remote_account!

    response = ValidationApi::PlatformAccounts::CreateApiTokenService.new.call(
      account_id: current_account.validation_account_id,
      name: params.fetch(:token_name, "leadpulse_web")
    )

    had_previous_token = current_account.validation_api_token_configured?
    current_account.persist_validation_api_token!(
      raw_token: response["raw_token"],
      token_prefix: response["token_prefix"],
      created_at: response["created_at"]
    )

    flash[:generated_api_token] = response["raw_token"]
    flash[:notice] = if had_previous_token
      "Novo token gerado com sucesso. O token anterior foi revogado automaticamente."
    else
      "Token gerado com sucesso. Copie agora, porque ele não será exibido novamente."
    end

    redirect_to api_token_platform_settings_path
  rescue ValidationApi::Error => e
    flash.now[:alert] = e.message
    render :api_token, status: :unprocessable_entity
  end

  private

  def company_params
    params.require(:account).permit(
      :validation_company_name,
      :validation_spoken_company_name,
      :validation_owner_name,
      :validation_owner_email,
      :validation_calling_profile
    )
  end

  def twilio_params
    params.require(:account).permit(
      :validation_twilio_account_sid,
      :validation_twilio_auth_token,
      :validation_twilio_webhook_base_url,
      :validation_twilio_phone_numbers_text
    )
  end

  def openai_params
    params.require(:account).permit(
      :validation_openai_api_key,
      :validation_openai_realtime_model,
      :validation_openai_realtime_voice,
      :validation_openai_realtime_output_speed,
      :validation_openai_style_instructions
    )
  end

  def lgpd_params
    params.require(:account).permit(
      :lgpd_legal_basis,
      :lgpd_purpose,
      :lgpd_notice_script,
      :lgpd_evidence_retention_days,
      :lgpd_recording_allowed,
      :lgpd_controller_name,
      :lgpd_controller_email,
      :lgpd_stop_automatic_calls_on_refusal
    )
  end

  def build_twilio_phone_numbers
    twilio_params[:validation_twilio_phone_numbers_text].to_s.lines.map(&:strip).reject(&:blank?).uniq.map do |phone_number|
      phone_number = SupplierImports::PhoneStandard.callback_e164(phone_number)
      {
        phone_number: phone_number,
        friendly_name: "Linha #{phone_number[-4, 4]}",
        is_active: true,
        max_concurrent_calls: 1
      }
    end
  end

  def ensure_remote_account!
    ValidationApi::PlatformAccountProvisioner.new(current_account).ensure_account!
  end

  def persist_account_snapshot!(response)
    ValidationApi::PlatformAccountProvisioner.new(current_account).persist_account_snapshot!(response)
  end

  def missing_required_fields(params_hash, label_map)
    label_map.each_with_object([]) do |(field, label), missing|
      missing << label if params_hash[field].to_s.strip.blank?
    end
  end

  def render_invalid_settings(template)
    flash.now[:alert] = current_account.errors.full_messages.to_sentence
    render template, status: :unprocessable_entity
  end
end
