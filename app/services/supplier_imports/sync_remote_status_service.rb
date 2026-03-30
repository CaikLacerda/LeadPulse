module SupplierImports
  class SyncRemoteStatusService
    def initialize(user:, supplier_import:)
      @user = user
      @supplier_import = supplier_import
    end

    def call
      return if @user.validation_api_token_value.blank? || @supplier_import.remote_batch_id.blank?

      response = show_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        batch_id: @supplier_import.remote_batch_id
      )
      status = map_status(response)

      @supplier_import.update!(
        remote_batch_status: response['batch_status'],
        response_payload: response,
        result_ready: response['result_ready'] || false,
        last_synced_at: Time.current,
        finished_at: response['finished_at'],
        error_message: error_message_for(response, status),
        status: status
      )
    end

    private

    def show_remote_batch_service
      if @supplier_import.supplier_validation?
        ValidationApi::SupplierValidations::ShowBatchService.new
      else
        ValidationApi::Validations::ShowBatchService.new
      end
    end

    def map_status(response)
      case response['batch_status']
      when 'completed'
        completed_with_failures?(response) ? SupplierImport::LOCAL_STATUS_ERROR : SupplierImport::LOCAL_STATUS_COMPLETED
      when 'processing', 'accepted'
        SupplierImport::LOCAL_STATUS_PROCESSING
      when nil
        @supplier_import.status
      else
        SupplierImport::LOCAL_STATUS_ERROR
      end
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
