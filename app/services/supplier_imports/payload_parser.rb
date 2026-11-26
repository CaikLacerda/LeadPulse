require "csv"
require "json"
require "roo"
require "tempfile"

module SupplierImports
  class PayloadParser
    MAX_FILE_BYTES = 10.megabytes
    MAX_ROWS = 1_000

    HEADER_ALIASES = {
      external_id: %w[external_id id_registro id codigo code],
      client_name: %w[client_name nome_cliente nome_do_cliente nome_fornecedor nome_do_fornecedor supplier_name empresa nome company_name],
      cnpj: %w[cnpj documento document cpf_cnpj cnpj_cpf],
      phone: %w[phone telefone telefone_principal celular numero],
      email: %w[email e_mail correio_eletronico],
      city: %w[city cidade municipio],
      state: %w[state estado uf],
      notes: %w[notes observacao observacoes descricao],
      segment_name: %w[segment_name segmento],
      callback_phone: %w[callback_phone telefone_retorno telefone_de_retorno telefone_callback],
      callback_contact_name: %w[callback_contact_name contato_retorno contato_de_retorno nome_contato_retorno],
      expected_result: %w[expected_result resultado_esperado resultado_manual classificacao_manual status_manual],
      manual_validation_seconds: %w[manual_validation_seconds manual_duration_seconds tempo_manual_segundos tempo_manual_seconds]
    }.freeze

    REQUIRED_FIELD_LABELS = {
      client_name: "Empresa",
      cnpj: "CNPJ",
      phone: "Telefone"
    }.freeze

    RECORD_SIGNAL_FIELDS = %i[client_name cnpj phone email].freeze

    Result = Struct.new(:records, :invalid_rows, :total_rows, :metadata, :headers, keyword_init: true)

    def initialize(file_bytes:, filename:, separator: ",", workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL)
      @file_bytes = file_bytes
      @filename = filename.to_s
      @separator = separator.presence || ","
      @workflow_kind = workflow_kind.presence || SupplierImport::WORKFLOW_KIND_CADASTRAL
    end

    def call
      validate_file_size!
      rows = load_rows
      if rows.size > MAX_ROWS
        raise ArgumentError, "A planilha excede o limite de #{MAX_ROWS} registros por lote."
      end
      valid_records = []
      invalid_rows = []
      logical_index = 0
      metadata = {}
      seen_phones = {}

      rows.each do |row|
        next if blank_row?(row)

        normalized = normalize_row(row)
        collect_metadata!(metadata, normalized)
        next if record_data_blank?(normalized)

        logical_index += 1
        errors = required_fields.filter_map do |field|
          "#{REQUIRED_FIELD_LABELS.fetch(field, field.to_s.humanize)} não informado" if normalized[field].blank?
        end

        if errors.any?
          invalid_rows << {
            row_number: logical_index,
            errors: errors,
            data: normalized.transform_keys(&:to_s)
          }
          next
        end

        phone_key = deduplication_key(normalized[:phone])
        if phone_key.present? && seen_phones.key?(phone_key)
          invalid_rows << {
            row_number: logical_index,
            errors: [ "Telefone duplicado no arquivo (primeira ocorrência na linha #{seen_phones[phone_key]})" ],
            data: normalized.transform_keys(&:to_s)
          }
          next
        end

        seen_phones[phone_key] = logical_index if phone_key.present?
        valid_records << build_record(normalized, logical_index)
      end

      Result.new(
        records: valid_records,
        invalid_rows: invalid_rows,
        total_rows: valid_records.size + invalid_rows.size,
        metadata: metadata,
        headers: @headers || []
      )
    end

    private

    def load_rows
      ext = File.extname(@filename).downcase

      case ext
      when ".csv"
        parse_csv
      when ".json"
        parse_json
      when ".xlsx"
        parse_xlsx
      else
        raise ArgumentError, "Formato não suportado. Use CSV, XLSX ou JSON."
      end
    end

    def parse_csv
      content = @file_bytes.dup.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "CSV inválido: o arquivo não está em UTF-8." unless content.valid_encoding?

      parsed = CSV.parse(content, headers: true, col_sep: @separator)
      @headers = Array(parsed.headers).map { |value| normalize_header(value) }.reject(&:blank?)
      parsed.map(&:to_h)
    rescue CSV::MalformedCSVError => e
      raise ArgumentError, "CSV inválido: #{e.message}"
    end

    def parse_json
      parsed = JSON.parse(@file_bytes)
      rows = parsed.is_a?(Hash) ? parsed["records"] || parsed["rows"] : parsed
      unless rows.is_a?(Array) && rows.all? { |row| row.respond_to?(:to_h) }
        raise ArgumentError, "JSON inválido: use uma lista de registros ou a chave records."
      end

      normalized_rows = Array(rows)
      @headers = Array(normalized_rows.first&.to_h&.keys).map { |value| normalize_header(value) }.reject(&:blank?)
      normalized_rows
    rescue JSON::ParserError => e
      raise ArgumentError, "JSON inválido: #{e.message}"
    end

    def parse_xlsx
      Tempfile.create([ "leadpulse-import", ".xlsx" ]) do |file|
        file.binmode
        file.write(@file_bytes)
        file.flush

        sheet = Roo::Spreadsheet.open(file.path, extension: :xlsx).sheet(0)
        headers = Array(sheet.row(1)).map { |value| normalize_header(value) }
        @headers = headers.reject(&:blank?)

        (2..sheet.last_row).map do |row_index|
          values = Array(sheet.row(row_index))
          headers.each_with_index.to_h { |header, index| [ header, values[index] ] }
        end
      end
    rescue Zip::Error, Roo::Error, IOError => e
      raise ArgumentError, "Planilha XLSX inválida: #{e.message}"
    end

    def normalize_row(row)
      row_hash = row.to_h.transform_keys { |key| normalize_header(key) }

      {
        external_id: SupplierImports::ValueNormalizer.identifier(value_for(row_hash, :external_id)),
        client_name: SupplierImports::ValueNormalizer.text(value_for(row_hash, :client_name)),
        cnpj: SupplierImports::ValueNormalizer.identifier(value_for(row_hash, :cnpj)),
        phone: SupplierImports::ValueNormalizer.identifier(value_for(row_hash, :phone)),
        email: SupplierImports::ValueNormalizer.text(value_for(row_hash, :email)),
        city: SupplierImports::ValueNormalizer.text(value_for(row_hash, :city)),
        state: SupplierImports::ValueNormalizer.text(value_for(row_hash, :state)),
        notes: SupplierImports::ValueNormalizer.text(value_for(row_hash, :notes)),
        segment_name: SupplierImports::ValueNormalizer.text(value_for(row_hash, :segment_name)),
        callback_phone: SupplierImports::ValueNormalizer.identifier(value_for(row_hash, :callback_phone)),
        callback_contact_name: SupplierImports::ValueNormalizer.text(value_for(row_hash, :callback_contact_name)),
        expected_result: SupplierImports::ValueNormalizer.text(value_for(row_hash, :expected_result)),
        manual_validation_seconds: SupplierImports::ValueNormalizer.identifier(value_for(row_hash, :manual_validation_seconds))
      }
    end

    def build_record(normalized, logical_index)
      base = {
        external_id: normalized[:external_id].presence || logical_index.to_s,
        phone: normalized[:phone],
        email: normalized[:email].presence,
        expected_result: normalized[:expected_result].presence,
        manual_validation_seconds: normalized[:manual_validation_seconds].presence
      }

      if supplier_validation?
        base.merge(
          supplier_name: normalized[:client_name],
          city: normalized[:city].presence,
          state: normalized[:state].presence,
          notes: normalized[:notes].presence
        ).compact
      else
        base.merge(
          client_name: normalized[:client_name],
          cnpj: normalized[:cnpj]
        ).compact
      end
    end

    def required_fields
      if supplier_validation?
        %i[client_name phone]
      else
        %i[client_name cnpj phone]
      end
    end

    def supplier_validation?
      @workflow_kind == SupplierImport::WORKFLOW_KIND_SUPPLIER
    end

    def collect_metadata!(metadata, normalized)
      return unless supplier_validation?

      metadata[:segment_name] ||= normalized[:segment_name].presence
      metadata[:callback_phone] ||= normalized[:callback_phone].presence
      metadata[:callback_contact_name] ||= normalized[:callback_contact_name].presence
    end

    def value_for(row, key)
      aliases = HEADER_ALIASES.fetch(key)
      aliases.each do |possible_key|
        value = row[possible_key]
        return value if value.present?
      end
      nil
    end

    def normalize_header(value)
      I18n.transliterate(value.to_s)
        .strip
        .downcase
        .gsub(/[^a-z0-9]+/, "_")
        .gsub(/\A_+|_+\z/, "")
    end

    def validate_file_size!
      if @file_bytes.nil? || @file_bytes.empty?
        raise ArgumentError, "O arquivo enviado está vazio."
      end
      return if @file_bytes.bytesize <= MAX_FILE_BYTES

      raise ArgumentError, "O arquivo excede o limite de 10 MB."
    end

    def blank_row?(row)
      row.to_h.values.all? { |value| value.to_s.strip.blank? }
    end

    def record_data_blank?(row)
      RECORD_SIGNAL_FIELDS.all? { |field| row[field].blank? }
    end

    def deduplication_key(phone)
      digits = phone.to_s.gsub(/\D/, "")
      return if digits.blank?

      digits = digits.delete_prefix("55") if digits.start_with?("55") && digits.length > 11
      digits
    end
  end
end
