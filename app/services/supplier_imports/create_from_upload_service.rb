require 'securerandom'

module SupplierImports
  class CreateFromUploadService
    Result = Struct.new(:success?, :import, :error_message, keyword_init: true)

    def initialize(user:, file:, separator: ',', workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL, segment_name: nil, callback_phone: nil, callback_contact_name: nil, privacy_notice: {})
      @user = user
      @file = file
      @separator = separator
      @workflow_kind = workflow_kind.presence || SupplierImport::WORKFLOW_KIND_CADASTRAL
      @segment_name = segment_name
      @callback_phone = callback_phone
      @callback_contact_name = callback_contact_name
      @privacy_notice = privacy_notice
    end

    def call
      file_bytes = @file.read
      parser = SupplierImports::PayloadParser.new(
        file_bytes: file_bytes,
        filename: @file.original_filename,
        separator: @separator,
        workflow_kind: @workflow_kind
      )
      parsed = parser.call
      resolved_segment_metadata = resolved_segment_metadata(parsed)
      records_for_request = records_for_request(parsed.records)
      privacy_blocked_records = privacy_blocked_records(records_for_request)
      records_for_request -= privacy_blocked_records
      reference_labels = reference_labels(parsed.records)

      validate_workflow_requirements!(resolved_segment_metadata)

      if parsed.records.empty? || records_for_request.empty?
        return Result.new(success?: false, error_message: 'Nenhuma linha válida foi encontrada no arquivo.')
      end

      batch_id = generate_batch_id
      supplier_import = @user.supplier_imports.new(
        file_name: @file.original_filename,
        xlsx_data: file_bytes,
        status: SupplierImport::LOCAL_STATUS_PENDING,
        workflow_kind: @workflow_kind,
        source: SupplierImport::SOURCE_UPLOAD,
        remote_batch_id: batch_id,
        total_rows: parsed.total_rows,
        valid_rows: records_for_request.size,
        invalid_rows: parsed.invalid_rows.size + privacy_blocked_records.size,
        request_payload: build_request_payload(batch_id, records_for_request, resolved_segment_metadata),
        import_metadata: {
          file_name: @file.original_filename,
          invalid_rows: parsed.invalid_rows,
          segment_name: resolved_segment_metadata[:segment_name],
          callback_phone: resolved_segment_metadata[:callback_phone],
          callback_contact_name: resolved_segment_metadata[:callback_contact_name],
          reference_labels: reference_labels.presence,
          privacy_blocked_rows: privacy_blocked_records.size,
          phone_standard: SupplierImports::PhoneStandard::LABEL,
          privacy_notice: privacy_notice_payload
        }.compact
      )

      if supplier_import.save
        Result.new(success?: true, import: supplier_import)
      else
        Result.new(success?: false, error_message: supplier_import.errors.full_messages.to_sentence)
      end
    rescue ArgumentError => e
      Result.new(success?: false, error_message: e.message)
    end

    private

    def validate_workflow_requirements!(resolved_segment_metadata)
      return unless @workflow_kind == SupplierImport::WORKFLOW_KIND_SUPPLIER

      if resolved_segment_metadata[:segment_name].blank? || resolved_segment_metadata[:callback_phone].blank?
        raise ArgumentError, 'Para importar um lote de segmento, use a planilha baixada na Busca de fornecedores.'
      end
    end

    def generate_batch_id
      "lp_batch_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}"
    end

    def build_request_payload(batch_id, records, resolved_segment_metadata)
      base = {
        batch_id: batch_id,
        source: SupplierImport::SOURCE_UPLOAD,
        privacy_notice: privacy_notice_payload,
        records: records
      }

      return base unless @workflow_kind == SupplierImport::WORKFLOW_KIND_SUPPLIER

      base.merge(
        segment_name: resolved_segment_metadata[:segment_name],
        callback_phone: SupplierImports::PhoneStandard.e164(resolved_segment_metadata[:callback_phone]),
        callback_contact_name: resolved_segment_metadata[:callback_contact_name].presence
      ).compact
    end

    def privacy_notice_payload
      @privacy_notice_payload ||= SupplierImports::PrivacyNoticePayload.build(
        workflow_kind: @workflow_kind,
        user: @user,
        overrides: @privacy_notice
      )
    end

    def resolved_segment_metadata(parsed)
      {
        segment_name: @segment_name.presence || parsed.metadata&.dig(:segment_name),
        callback_phone: @callback_phone.presence || parsed.metadata&.dig(:callback_phone),
        callback_contact_name: @callback_contact_name.presence || parsed.metadata&.dig(:callback_contact_name)
      }
    end

    def records_for_request(records)
      records.map do |record|
        record.except(:expected_result, 'expected_result', :manual_validation_seconds, 'manual_validation_seconds').tap do |payload_record|
          payload_record[:phone] = SupplierImports::PhoneStandard.e164(payload_record[:phone])
          payload_record['phone'] = SupplierImports::PhoneStandard.e164(payload_record['phone']) if payload_record.key?('phone')
        end
      end
    end

    def privacy_blocked_records(records)
      return [] unless @user.lgpd_stop_automatic_calls_on_refusal?

      blocked_numbers = SupplierImports::PrivacyRefusalRegistry.blocked_phone_numbers_for(@user)
      records.select do |record|
        SupplierImports::PrivacyRefusalRegistry.blocked?(record[:phone] || record['phone'], blocked_numbers)
      end
    end

    def reference_labels(records)
      records.filter_map do |record|
        expected_result = record[:expected_result].presence || record['expected_result'].presence
        next if expected_result.blank?

        {
          external_id: record[:external_id].presence || record['external_id'],
          expected_result: expected_result,
          manual_validation_seconds: record[:manual_validation_seconds].presence || record['manual_validation_seconds'].presence
        }.compact
      end
    end
  end
end
