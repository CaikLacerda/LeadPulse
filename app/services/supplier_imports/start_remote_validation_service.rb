require "securerandom"

module SupplierImports
  # Envia o lote à API de validação. O início é reivindicado sob lock antes da chamada
  # externa: um segundo clique (ou um retry depois de timeout) não cria outro lote remoto.
  # O batch_id enviado fica gravado e só muda depois de uma tentativa confirmada pela API;
  # se o resultado da tentativa anterior é desconhecido, o mesmo id é reenviado e a API
  # responde com o lote já criado (idempotência por batch_id + conteúdo).
  class StartRemoteValidationService
    CLAIM_KEY = "remote_start_claimed_at".freeze
    CLAIM_TTL = 2.minutes

    def initialize(account:, supplier_import:)
      @account = account
      @supplier_import = supplier_import
    end

    def call
      raise ActiveRecord::RecordNotFound, "Lote não encontrado para esta conta." unless @supplier_import.account_id == @account.id

      raise ValidationApi::Error, "Gere o token da API antes de iniciar um lote." if @account.validation_api_token_value.blank?
      raise ValidationApi::Error, "Esse lote não possui request montada para envio." if @supplier_import.request_payload.blank? || @supplier_import.request_payload["records"].blank?

      normalized_payload = claim_start!
      response = create_remote_batch_service.call(
        api_token: @account.validation_api_token_value,
        payload: normalized_payload
      )
      persist_response!(normalized_payload, response)
      response
    rescue ValidationApi::Error
      release_claim!(normalized_payload) if normalized_payload
      raise
    end

    private

    def claim_start!
      @supplier_import.with_lock do
        raise ValidationApi::Error, "Esse lote só pode ser iniciado quando estiver pendente ou com erro." unless @supplier_import.startable?
        raise ValidationApi::Error, "O início deste lote já está em andamento. Aguarde alguns instantes." if claim_active?

        payload = normalized_request_payload
        new_attempt = payload["batch_id"] != @supplier_import.remote_batch_id
        previous_response = @supplier_import.response_payload
        if new_attempt && previous_response.is_a?(Hash) && previous_response.present?
          previous_response = previous_response.merge("batch_id" => previous_response["batch_id"].presence || @supplier_import.remote_batch_id)
        end
        @supplier_import.update!(
          response_payload: previous_response,
          request_payload: payload,
          remote_batch_id: payload["batch_id"],
          remote_batch_status: new_attempt ? nil : @supplier_import.remote_batch_status,
          import_metadata: @supplier_import.import_metadata.merge(CLAIM_KEY => Time.current.iso8601)
        )
        payload
      end
    end

    def persist_response!(payload, response)
      @supplier_import.with_lock do
        return if @supplier_import.remote_batch_id != payload["batch_id"]

        status_mapper = RemoteStatusMapper.new(supplier_import: @supplier_import)
        claimed_at = ValidationApi::Timestamp.parse(@supplier_import.import_metadata[CLAIM_KEY]) || Time.current
        if status_mapper.stale_response?(response, current_status: @supplier_import.status, current_remote_status: @supplier_import.remote_batch_status)
          @supplier_import.update!(validation_started_at: claimed_at, import_metadata: @supplier_import.import_metadata.except(CLAIM_KEY))
          return
        end

        previous = @supplier_import.response_payload
        if previous.is_a?(Hash) && (previous["batch_id"].blank? || previous["batch_id"] == payload["batch_id"])
          response = previous.merge(response)
        end
        response = RemoteEvidenceMerger.new(account: @account, supplier_import: @supplier_import).carry_over(response)
        status = status_mapper.local_status(
          response,
          fallback_status: SupplierImport::LOCAL_STATUS_PENDING
        )

        @supplier_import.update!(
          request_payload: payload,
          remote_batch_id: response["batch_id"].presence || payload["batch_id"],
          remote_batch_status: response["batch_status"],
          response_payload: response,
          result_ready: response["result_ready"] || false,
          validation_started_at: claimed_at,
          last_synced_at: Time.current,
          finished_at: ValidationApi::Timestamp.parse(response["finished_at"]),
          error_message: status_mapper.error_message(response, status: status),
          status: status,
          import_metadata: @supplier_import.import_metadata.except(CLAIM_KEY)
        )
      end
    end

    # A falha da chamada libera o lote para um novo clique, mantendo o batch_id enviado.
    def release_claim!(payload)
      @supplier_import.with_lock do
        next if @supplier_import.remote_batch_id != payload["batch_id"]

        @supplier_import.update!(import_metadata: @supplier_import.import_metadata.except(CLAIM_KEY))
      end
    end

    def claim_active?
      claimed_at = Time.zone.parse(@supplier_import.import_metadata[CLAIM_KEY].to_s)
      claimed_at.present? && claimed_at > CLAIM_TTL.ago
    rescue ArgumentError
      false
    end

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
        account: @account,
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
      Array(@account.validation_twilio_phone_numbers).filter_map do |item|
        value = item.is_a?(Hash) ? (item["phone_number"] || item[:phone_number]) : item
        normalized = SupplierImports::PhoneStandard.callback_e164(value)
        normalized if normalized.to_s.start_with?("+")
      end
    end

    # Id novo só para refazer um lote que a API confirmou (remote_batch_status presente).
    # Sem confirmação, a tentativa anterior pode ter criado o lote remoto: reenviar o mesmo id.
    def refreshed_batch_id(current_batch_id)
      if @supplier_import.errored? && @supplier_import.remote_batch_id.present? && @supplier_import.remote_batch_status.present?
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
