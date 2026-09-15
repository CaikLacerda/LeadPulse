require "securerandom"

module CommercialOpportunities
  class StartRemoteValidationService
    def initialize(user:, commercial_opportunity:)
      @user = user
      @commercial_opportunity = commercial_opportunity
    end

    def call
      raise ValidationApi::Error, "Gere o token da API antes de iniciar a coleta comercial." if @user.validation_api_token_value.blank?

      payload = prepare_payload!
      return current_remote_snapshot if payload.nil?

      response = create_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        payload: payload
      )
      ensure_matching_batch_id!(payload, response)
      persist_response!(payload, response)
      response
    rescue ValidationApi::Error => error
      persist_error!(payload, error) if payload.present?
      raise
    end

    private

    def prepare_payload!
      prepared_payload = nil

      @commercial_opportunity.with_lock do
        if active_request_already_persisted?
          next
        end

        raise ValidationApi::Error, "Este retorno comercial não está disponível para início." unless @commercial_opportunity.startable?

        mapper = RemoteStatusMapper.new
        new_attempt = @commercial_opportunity.errored? && mapper.failed_remote_status?(@commercial_opportunity.remote_batch_status)
        payload = if new_attempt || @commercial_opportunity.request_payload.blank?
          build_payload(batch_id: new_attempt ? nil : @commercial_opportunity.remote_batch_id)
        else
          @commercial_opportunity.request_payload.deep_stringify_keys
        end

        payload_batch_id = payload["batch_id"].presence
        stored_batch_id = @commercial_opportunity.remote_batch_id.presence
        if !new_attempt && payload_batch_id.present? && stored_batch_id.present? && payload_batch_id != stored_batch_id
          raise ValidationApi::Error, "O identificador persistido da coleta comercial diverge do payload original."
        end

        batch_id = payload_batch_id || stored_batch_id || generate_batch_id
        payload["batch_id"] = batch_id
        @commercial_opportunity.update!(
          request_payload: payload,
          remote_batch_id: batch_id,
          remote_batch_status: new_attempt ? nil : @commercial_opportunity.remote_batch_status,
          status: CommercialOpportunity::STATUS_PROCESSING,
          started_at: new_attempt ? Time.current : (@commercial_opportunity.started_at || Time.current),
          error_message: nil
        )
        prepared_payload = payload.deep_dup
      end

      prepared_payload
    end

    def active_request_already_persisted?
      @commercial_opportunity.processing? &&
        @commercial_opportunity.remote_batch_id.present? &&
        @commercial_opportunity.request_payload.present?
    end

    def current_remote_snapshot
      response = @commercial_opportunity.reload.response_payload
      if response.is_a?(Hash) && response.present? && response["batch_id"].to_s == @commercial_opportunity.remote_batch_id.to_s
        return response.deep_dup
      end

      {
        "batch_id" => @commercial_opportunity.remote_batch_id,
        "batch_status" => @commercial_opportunity.remote_batch_status.presence || "processing",
        "result_ready" => @commercial_opportunity.result_ready?
      }
    end

    def persist_response!(payload, response)
      @commercial_opportunity.with_lock do
        return if @commercial_opportunity.remote_batch_id.present? && @commercial_opportunity.remote_batch_id != payload["batch_id"]

        mapper = RemoteStatusMapper.new
        status = mapper.local_status(
          response,
          fallback_status: @commercial_opportunity.status
        )

        if mapper.stale_response?(
          response,
          current_status: @commercial_opportunity.status,
          current_remote_status: @commercial_opportunity.remote_batch_status
        )
          @commercial_opportunity.update!(last_synced_at: Time.current)
          return
        end

        @commercial_opportunity.update!(
          request_payload: payload,
          response_payload: response,
          remote_batch_id: payload["batch_id"],
          remote_batch_status: response["batch_status"].presence || @commercial_opportunity.remote_batch_status,
          status: status,
          result_ready: @commercial_opportunity.result_ready? || response["result_ready"] == true,
          last_synced_at: Time.current,
          finished_at: response["finished_at"].presence || @commercial_opportunity.finished_at,
          error_message: mapper.error_message(response, status: status)
        )
      end
    end

    def persist_error!(payload, error)
      @commercial_opportunity.with_lock do
        return unless @commercial_opportunity.remote_batch_id == payload["batch_id"]
        return if @commercial_opportunity.completed?

        @commercial_opportunity.update!(
          status: CommercialOpportunity::STATUS_ERROR,
          error_message: error.message,
          last_synced_at: Time.current
        )
      end
    end

    def build_payload(batch_id: nil)
      {
        "batch_id" => batch_id.presence || generate_batch_id,
        "source" => SupplierImport::SOURCE_UPLOAD,
        "privacy_notice" => SupplierImports::PrivacyNoticePayload.build(
          workflow_kind: "commercial_validation",
          user: @user,
          overrides: {
            "purpose" => SupplierImports::PrivacyNoticePayload::PURPOSES.fetch("commercial_validation")
          }
        ).stringify_keys,
        "records" => [
          {
            "external_id" => "commercial_opportunity_#{@commercial_opportunity.id}",
            "supplier_name" => @commercial_opportunity.supplier_name,
            "phone" => SupplierImports::PhoneStandard.callback_e164(@commercial_opportunity.callback_phone),
            "preferred_callback_time" => @commercial_opportunity.callback_preferred_time
          }
        ]
      }
    end

    def generate_batch_id
      "lp_commercial_batch_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end

    def ensure_matching_batch_id!(payload, response)
      returned_batch_id = response["batch_id"].presence
      return if returned_batch_id.blank? || returned_batch_id == payload["batch_id"]

      raise ValidationApi::Error, "A API respondeu com um identificador diferente da coleta comercial enviada."
    end

    def create_remote_batch_service
      ValidationApi::CommercialValidations::CreateBatchService.new
    end
  end
end
