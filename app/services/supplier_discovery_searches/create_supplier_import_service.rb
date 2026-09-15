require "securerandom"

module SupplierDiscoverySearches
  class CreateSupplierImportService
    Result = Struct.new(:success?, :import, :error_message, keyword_init: true)

    def initialize(user:, search:)
      @user = user
      @search = search
    end

    def call
      return ownership_error unless @search.user_id == @user.id

      records = filter_privacy_blocked_records(@search.valid_supplier_candidates)
      if records.empty? && privacy_blocked_records_count.positive?
        return Result.new(
          success?: false,
          error_message: "Todos os fornecedores dessa busca estão bloqueados por uma recusa LGPD anterior."
        )
      end
      return Result.new(success?: false, error_message: "Essa busca não possui fornecedores com nome e telefone para validar.") if records.empty?

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
        invalid_rows: @search.invalid_supplier_candidates_count + privacy_blocked_records_count,
        request_payload: {
          batch_id: batch_id,
          source: SupplierImport::SOURCE_UPLOAD,
          privacy_notice: privacy_notice_payload,
          segment_name: @search.segment_name,
          records: records
        }.compact,
        import_metadata: {
          supplier_discovery_search_id: @search.id,
          search_id: @search.search_id,
          region: @search.region,
          mode: @search.mode,
          generated_at: @search.generated_at,
          skipped_candidates: @search.suppliers.size - records.size,
          privacy_blocked_rows: privacy_blocked_records_count,
          privacy_notice: privacy_notice_payload
        }.compact
      )

      if import.save
        Result.new(success?: true, import:)
      else
        Result.new(success?: false, error_message: import.errors.full_messages.to_sentence)
      end
    end

    private

    def ownership_error
      Result.new(success?: false, error_message: "Busca de fornecedores não encontrada para esta conta.")
    end

    def generate_batch_id
      "lp_supplier_batch_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end

    def privacy_notice_payload
      @privacy_notice_payload ||= SupplierImports::PrivacyNoticePayload.build(
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        user: @user
      )
    end

    def filter_privacy_blocked_records(records)
      @privacy_blocked_records_count = 0
      return records unless @user.lgpd_stop_automatic_calls_on_refusal?

      blocked_numbers = SupplierImports::PrivacyRefusalRegistry.blocked_phone_numbers_for(@user)
      records.reject do |record|
        blocked = SupplierImports::PrivacyRefusalRegistry.blocked?(record[:phone] || record["phone"], blocked_numbers)
        @privacy_blocked_records_count += 1 if blocked
        blocked
      end
    end

    def privacy_blocked_records_count
      @privacy_blocked_records_count.to_i
    end
  end
end
