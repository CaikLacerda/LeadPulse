require 'securerandom'

module SupplierImports
  class StartRemoteValidationService
    def initialize(user:, supplier_import:)
      @user = user
      @supplier_import = supplier_import
    end

    def call
      raise ValidationApi::Error, 'Gere o token da API antes de iniciar um lote.' if @user.validation_api_token_value.blank?
      raise ValidationApi::Error, 'Esse lote não possui request montada para envio.' if @supplier_import.request_payload.blank? || @supplier_import.request_payload['records'].blank?
      raise ValidationApi::Error, 'Esse lote só pode ser iniciado quando estiver pendente ou com erro.' unless @supplier_import.startable?

      normalized_payload = normalized_request_payload
      sent_batch_id = normalized_payload['batch_id']
      response = submit_remote_batch(normalized_payload)
      status = map_status(response)

      @supplier_import.update!(
        request_payload: normalized_payload,
        remote_batch_id: response['batch_id'].presence || sent_batch_id,
        remote_batch_status: response['batch_status'],
        response_payload: response,
        result_ready: response['result_ready'] || false,
        validation_started_at: Time.current,
        last_synced_at: Time.current,
        finished_at: response['finished_at'],
        error_message: error_message_for(response, status),
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

    def map_status(response)
      case response['batch_status']
      when 'completed'
        completed_with_failures?(response) ? SupplierImport::LOCAL_STATUS_ERROR : SupplierImport::LOCAL_STATUS_COMPLETED
      when 'processing', 'accepted'
        SupplierImport::LOCAL_STATUS_PROCESSING
      when 'failed', 'error'
        SupplierImport::LOCAL_STATUS_ERROR
      else
        SupplierImport::LOCAL_STATUS_PENDING
      end
    end

    def normalized_request_payload
      payload = @supplier_import.request_payload.deep_stringify_keys
      payload['batch_id'] = refreshed_batch_id(payload['batch_id'])
      payload['callback_phone'] = SupplierImports::ValueNormalizer.identifier(payload['callback_phone'])

      payload['records'] = Array(payload['records']).map do |record|
        normalized = record.deep_stringify_keys
        normalized['external_id'] = SupplierImports::ValueNormalizer.identifier(normalized['external_id'])
        normalized['phone'] = SupplierImports::ValueNormalizer.identifier(normalized['phone'])
        normalized['cnpj'] = SupplierImports::ValueNormalizer.identifier(normalized['cnpj'])
        normalized
      end

      payload
    end

    def submit_remote_batch(payload)
      create_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        payload: payload
      )
    rescue ValidationApi::Error => e
      raise e unless duplicate_batch_error?(e)

      payload['batch_id'] = generate_batch_id(payload['batch_id'])
      create_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        payload: payload
      )
    end

    def duplicate_batch_error?(error)
      error.status_code.to_i == 409 || error.message.to_s.downcase.include?('ja existe')
    end

    def refreshed_batch_id(current_batch_id)
      return current_batch_id if current_batch_id.present? && !@supplier_import.errored?

      generate_batch_id(current_batch_id)
    end

    def generate_batch_id(reference_batch_id = nil)
      prefix =
        if reference_batch_id.to_s.start_with?('lp_supplier_batch_')
          'lp_supplier_batch'
        else
          'lp_batch'
        end

      "#{prefix}_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end

    def completed_with_failures?(response)
      total_records = response['total_records'].to_i
      return false if total_records.zero?
      return false if supplier_validation_with_business_outcome?(response)

      summary = response['summary'].is_a?(Hash) ? response['summary'] : {}
      confirmed_records = summary['confirmed_by_call'].to_i + summary['confirmed_by_whatsapp'].to_i + summary['confirmed_by_email'].to_i
      validated_records = summary['validated_records'].to_i
      failed_records = summary['failed_records'].to_i
      invalid_phone = summary['invalid_phone'].to_i
      all_records_failed = Array(response['records']).presence&.all? do |record|
        %w[validation_failed invalid_phone error failed].include?(record['final_status'].to_s)
      end

      confirmed_records.zero? &&
        validated_records.zero? &&
        (failed_records >= total_records || invalid_phone >= total_records || all_records_failed)
    end

    def supplier_validation_with_business_outcome?(response)
      return false unless @supplier_import.supplier_validation?

      records = Array(response['records'])
      return false if records.empty?

      records.all? do |record|
        supplier_validation = record['supplier_validation'].is_a?(Hash) ? record['supplier_validation'] : {}
        outcome = supplier_validation['outcome'].to_s

        %w[qualified_supplier wrong_company does_not_supply_segment not_interested].include?(outcome) ||
          record['call_result'].to_s == 'rejected'
      end
    end

    def error_message_for(response, status)
      return nil unless status == SupplierImport::LOCAL_STATUS_ERROR

      summary = response['summary'].is_a?(Hash) ? response['summary'] : {}
      total_records = response['total_records'].to_i

      if total_records.positive? && summary['invalid_phone'].to_i >= total_records
        return 'Todos os registros foram encerrados por telefone inválido antes da ligação.'
      end

      Array(response['records']).filter_map { |record| record['observation'].presence }.first ||
        'O lote foi encerrado sem registros aptos para ligação.'
    end
  end
end
