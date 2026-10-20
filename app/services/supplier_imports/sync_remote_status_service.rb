module SupplierImports
  class SyncRemoteStatusService
    def initialize(account:, supplier_import:)
      @account = account
      @supplier_import = supplier_import
    end

    def call
      raise ActiveRecord::RecordNotFound, "Lote não encontrado para esta conta." unless @supplier_import.account_id == @account.id

      raise ValidationApi::Error, "Gere o token da API antes de consultar o status do lote." if @account.validation_api_token_value.blank?
      raise ValidationApi::Error, "Esse lote ainda não foi iniciado na API." if @supplier_import.remote_batch_id.blank?

      requested_batch_id = @supplier_import.remote_batch_id
      response = show_remote_batch_service.call(
        api_token: @account.validation_api_token_value,
        batch_id: requested_batch_id
      )
      response = remote_evidence_merger.call(response, batch_id: requested_batch_id)
      apply_response!(response, requested_batch_id: requested_batch_id)

      CommercialOpportunities::UpsertFromSupplierImportService.new(
        supplier_import: @supplier_import
      ).call
      response
    end

    private

    def remote_evidence_merger
      RemoteEvidenceMerger.new(account: @account, supplier_import: @supplier_import)
    end

    def apply_response!(response, requested_batch_id:)
      @supplier_import.with_lock do
        return if @supplier_import.remote_batch_id != requested_batch_id

        # Reloaded by with_lock: a concurrent privacy request must win over fetched evidence.
        response = RemoteEvidenceMerger.new(account: @account, supplier_import: @supplier_import).carry_over(response)
        status_mapper = RemoteStatusMapper.new(supplier_import: @supplier_import)
        if status_mapper.stale_response?(
          response,
          current_status: @supplier_import.status,
          current_remote_status: @supplier_import.remote_batch_status
        )
          @supplier_import.update!(last_synced_at: Time.current)
          return
        end

        status = status_mapper.local_status(
          response,
          fallback_status: @supplier_import.status
        )
        @supplier_import.update!(
          remote_batch_status: response["batch_status"].presence || @supplier_import.remote_batch_status,
          response_payload: response,
          result_ready: @supplier_import.result_ready? || response["result_ready"] == true,
          last_synced_at: Time.current,
          finished_at: ValidationApi::Timestamp.parse(response["finished_at"]) || @supplier_import.finished_at,
          error_message: status_mapper.error_message(response, status: status),
          status: status
        )
      end
    end

    def show_remote_batch_service
      if @supplier_import.supplier_validation?
        ValidationApi::SupplierValidations::ShowBatchService.new
      else
        ValidationApi::Validations::ShowBatchService.new
      end
    end
  end
end
