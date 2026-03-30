require 'securerandom'

module SupplierDiscoverySearches
  class CreateSupplierImportService
    Result = Struct.new(:success?, :import, :error_message, keyword_init: true)

    def initialize(user:, search:)
      @user = user
      @search = search
    end

    def call
      records = @search.valid_supplier_candidates
      return Result.new(success?: false, error_message: 'Essa busca não possui fornecedores com nome e telefone para validar.') if records.empty?

      batch_id = generate_batch_id
      import = @user.supplier_imports.new(
        file_name: @search.download_filename,
        xlsx_data: @search.results_xlsx_data,
        status: SupplierImport::LOCAL_STATUS_PENDING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_SUPPLIER_DISCOVERY,
        remote_batch_id: batch_id,
        total_rows: @search.suppliers.size,
        valid_rows: records.size,
        invalid_rows: @search.invalid_supplier_candidates_count,
        request_payload: {
          batch_id: batch_id,
          source: SupplierImport::SOURCE_UPLOAD,
          segment_name: @search.segment_name,
          callback_phone: @search.callback_phone,
          callback_contact_name: @search.callback_contact_name.presence,
          records: records
        }.compact,
        import_metadata: {
          supplier_discovery_search_id: @search.id,
          search_id: @search.search_id,
          region: @search.region,
          mode: @search.mode,
          generated_at: @search.generated_at,
          skipped_candidates: @search.suppliers.size - records.size
        }.compact
      )

      if import.save
        Result.new(success?: true, import:)
      else
        Result.new(success?: false, error_message: import.errors.full_messages.to_sentence)
      end
    end

    private

    def generate_batch_id
      "lp_supplier_batch_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end
  end
end
