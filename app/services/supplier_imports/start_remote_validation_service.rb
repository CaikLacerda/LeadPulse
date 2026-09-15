require "securerandom"

module SupplierImports
  class StartRemoteValidationService
    def initialize(user:, supplier_import:)
      @user = user
      @supplier_import = supplier_import
    end

    def call
      raise ValidationApi::Error, "Gere o token da API antes de iniciar um lote." if @user.validation_api_token_value.blank?
      raise ValidationApi::Error, "Esse lote não possui request montada para envio." if @supplier_import.request_payload.blank? || @supplier_import.request_payload["records"].blank?
      raise ValidationApi::Error, "Esse lote só pode ser iniciado quando estiver pendente ou com erro." unless @supplier_import.startable?

      normalized_payload = normalized_request_payload
      sent_batch_id = normalized_payload["batch_id"]
      response = create_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        payload: normalized_payload
      )
      status_mapper = RemoteStatusMapper.new(supplier_import: @supplier_import)
      status = status_mapper.local_status(
        response,
        fallback_status: SupplierImport::LOCAL_STATUS_PENDING
      )

      @supplier_import.update!(
        request_payload: normalized_payload,
        remote_batch_id: response["batch_id"].presence || sent_batch_id,
        remote_batch_status: response["batch_status"],
        response_payload: response,
        result_ready: response["result_ready"] || false,
        validation_started_at: Time.current,
        last_synced_at: Time.current,
        finished_at: response["finished_at"],
        error_message: status_mapper.error_message(response, status: status),
        status: status
      )

      response
    end

    private

    def create_remote_batch_service
      if @supplier_import.supplier_validation?
        ValidationApi::SupplierValidations::CreateBatchService.new
      else
        ValidationApi::Validations::CreateBatchService.new
      end
    end

    def normalized_request_payload
      payload = @supplier_import.request_payload.deep_stringify_keys
      payload["batch_id"] = refreshed_batch_id(payload["batch_id"])
      payload["privacy_notice"] = SupplierImports::PrivacyNoticePayload.build(
        workflow_kind: @supplier_import.workflow_kind,
        user: @user,
        overrides: payload["privacy_notice"].presence ||
          @supplier_import.import_metadata["privacy_notice"].presence
      ).stringify_keys
      payload["callback_phone"] = normalized_callback_phone(payload["callback_phone"])

      payload["records"] = Array(payload["records"]).map do |record|
        normalized = record.deep_stringify_keys
        normalized["external_id"] = SupplierImports::ValueNormalizer.identifier(normalized["external_id"])
        normalized["phone"] = SupplierImports::PhoneStandard.e164(normalized["phone"])
        normalized["cnpj"] = SupplierImports::ValueNormalizer.identifier(normalized["cnpj"])
        normalized
      end

      payload
    end

    def normalized_callback_phone(value)
      normalized = SupplierImports::PhoneStandard.callback_e164(value)

      configured_twilio_phone_numbers.each do |twilio_phone|
        return twilio_phone if normalized == "+55#{twilio_phone.delete_prefix('+')}"
      end

      normalized
    end

    def configured_twilio_phone_numbers
      Array(@user.validation_twilio_phone_numbers).filter_map do |item|
        value = item.is_a?(Hash) ? (item["phone_number"] || item[:phone_number]) : item
        normalized = SupplierImports::PhoneStandard.callback_e164(value)
        normalized if normalized.to_s.start_with?("+")
      end
    end

    def refreshed_batch_id(current_batch_id)
      if @supplier_import.errored? && @supplier_import.remote_batch_id.present?
        return generate_batch_id(current_batch_id)
      end

      return current_batch_id if current_batch_id.present?
      return @supplier_import.remote_batch_id if @supplier_import.remote_batch_id.present?

      generate_batch_id(current_batch_id)
    end

    def generate_batch_id(reference_batch_id = nil)
      prefix =
        if reference_batch_id.to_s.start_with?("lp_supplier_batch_")
          "lp_supplier_batch"
        else
          "lp_batch"
        end

      "#{prefix}_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end
  end
end
