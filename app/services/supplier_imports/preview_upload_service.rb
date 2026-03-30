module SupplierImports
  class PreviewUploadService
    SAMPLE_LIMIT = 4

    Result = Struct.new(:success?, :preview, :error_message, keyword_init: true)

    COLUMN_LABELS = {
      "external_id" => "Registro",
      "client_name" => "Empresa",
      "supplier_name" => "Empresa",
      "cnpj" => "CNPJ",
      "phone" => "Telefone",
      "email" => "E-mail",
      "city" => "Cidade",
      "state" => "UF",
      "notes" => "Observação",
      "segment_name" => "Segmento",
      "callback_phone" => "Telefone de retorno",
      "callback_contact_name" => "Contato de retorno"
    }.freeze

    def initialize(file:, separator: ",", workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL)
      @file = file
      @separator = separator
      @workflow_kind = workflow_kind.presence || SupplierImport::WORKFLOW_KIND_CADASTRAL
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
      metadata = resolved_segment_metadata(parsed)
      warnings = build_warnings(parsed, metadata)

      Result.new(
        success?: true,
        preview: {
          file_name: @file.original_filename,
          workflow_kind: @workflow_kind,
          total_rows: parsed.total_rows,
          valid_rows: parsed.records.size,
          invalid_rows: parsed.invalid_rows.size,
          columns: Array(parsed.headers).map { |header| human_column_label(header) },
          metadata_fields: build_metadata_fields(metadata),
          warnings: warnings,
          import_allowed: parsed.records.any? && warnings.empty?,
          sample_headers: sample_headers(parsed),
          sample_rows: build_sample_rows(parsed),
          invalid_rows_preview: build_invalid_rows_preview(parsed)
        }
      )
    rescue ArgumentError => e
      Result.new(success?: false, error_message: e.message)
    end

    private

    def supplier_validation?
      @workflow_kind == SupplierImport::WORKFLOW_KIND_SUPPLIER
    end

    def resolved_segment_metadata(parsed)
      {
        segment_name: parsed.metadata&.dig(:segment_name),
        callback_phone: parsed.metadata&.dig(:callback_phone),
        callback_contact_name: parsed.metadata&.dig(:callback_contact_name)
      }
    end

    def build_warnings(parsed, metadata)
      warnings = []
      warnings << "Nenhuma linha válida foi encontrada no arquivo." if parsed.records.empty?

      if supplier_validation? && (metadata[:segment_name].blank? || metadata[:callback_phone].blank?)
        warnings << "Para lote de segmento, a planilha precisa trazer segmento e telefone de retorno."
      end

      warnings
    end

    def sample_headers(parsed)
      sample = parsed.records.first(SAMPLE_LIMIT)
      headers = sample.flat_map(&:keys).uniq
      preferred_headers = supplier_validation? ? %w[external_id supplier_name phone city state notes] : %w[external_id client_name cnpj phone email]

      ordered = preferred_headers.select { |header| headers.include?(header.to_sym) || headers.include?(header) }
      remaining = headers.map(&:to_s) - ordered
      (ordered + remaining).first(6).map { |header| { key: header, label: human_column_label(header) } }
    end

    def build_sample_rows(parsed)
      headers = sample_headers(parsed)

      parsed.records.first(SAMPLE_LIMIT).map.with_index(1) do |record, index|
        {
          row_number: index,
          cells: headers.map do |header|
            value = record[header[:key].to_sym] || record[header[:key]]
            { key: header[:key], value: value.to_s }
          end
        }
      end
    end

    def build_invalid_rows_preview(parsed)
      parsed.invalid_rows.first(SAMPLE_LIMIT).map do |row|
        {
          row_number: row[:row_number],
          errors: Array(row[:errors]),
          summary: summarize_invalid_data(row[:data] || {})
        }
      end
    end

    def summarize_invalid_data(data)
      visible = data.slice("client_name", "phone", "cnpj", "segment_name", "callback_phone", "callback_contact_name")
      source = visible.presence || data

      source.filter_map do |key, value|
        next if value.blank?

        "#{human_column_label(key)}: #{value}"
      end.join(" | ")
    end

    def build_metadata_fields(metadata)
      metadata.compact.filter_map do |key, value|
        next if value.blank?

        {
          label: human_column_label(key),
          value: value
        }
      end
    end

    def human_column_label(header)
      COLUMN_LABELS.fetch(header.to_s, header.to_s.humanize)
    end
  end
end
