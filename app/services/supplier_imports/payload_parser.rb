require 'csv'
require 'json'
require 'roo'
require 'tempfile'

module SupplierImports
  class PayloadParser
    HEADER_ALIASES = {
      external_id: %w[external_id id_registro id codigo code],
      client_name: %w[client_name nome_cliente nome_fornecedor supplier_name empresa nome company_name],
      cnpj: %w[cnpj documento document cpf_cnpj cnpj_cpf],
      phone: %w[phone telefone telefone_principal celular numero],
      email: %w[email e_mail correio_eletronico],
      city: %w[city cidade municipio],
      state: %w[state estado uf],
      notes: %w[notes observacao observacoes descricao],
      segment_name: %w[segment_name segmento],
      callback_phone: %w[callback_phone telefone_retorno telefone_callback],
      callback_contact_name: %w[callback_contact_name contato_retorno nome_contato_retorno]
    }.freeze

    Result = Struct.new(:records, :invalid_rows, :total_rows, :metadata, :headers, keyword_init: true)

    def initialize(file_bytes:, filename:, separator: ',', workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL)
      @file_bytes = file_bytes
      @filename = filename.to_s
      @separator = separator.presence || ','
      @workflow_kind = workflow_kind.presence || SupplierImport::WORKFLOW_KIND_CADASTRAL
    end

    def call
      rows = load_rows
      valid_records = []
      invalid_rows = []
      logical_index = 0
      metadata = {}

      rows.each do |row|
        next if blank_row?(row)

        logical_index += 1
        normalized = normalize_row(row)
        collect_metadata!(metadata, normalized)
        errors = required_fields.filter_map do |field|
          field.to_s.humanize if normalized[field].blank?
        end

        if errors.any?
          invalid_rows << {
            row_number: logical_index,
            errors: errors,
            data: normalized.transform_keys(&:to_s)
          }
          next
        end

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
      when '.csv'
        parse_csv
      when '.json'
        parse_json
      when '.xlsx'
        parse_xlsx
      else
        raise ArgumentError, 'Formato não suportado. Use CSV, XLSX ou JSON.'
      end
    end

    def parse_csv
      parsed = CSV.parse(@file_bytes.force_encoding('UTF-8'), headers: true, col_sep: @separator)
      @headers = Array(parsed.headers).map { |value| normalize_header(value) }.reject(&:blank?)
      parsed.map(&:to_h)
    end

    def parse_json
      parsed = JSON.parse(@file_bytes)
      rows = parsed.is_a?(Hash) ? parsed['records'] || parsed['rows'] : parsed
      normalized_rows = Array(rows)
      @headers = Array(normalized_rows.first&.to_h&.keys).map { |value| normalize_header(value) }.reject(&:blank?)
      normalized_rows
    rescue JSON::ParserError => e
      raise ArgumentError, "JSON inválido: #{e.message}"
    end

    def parse_xlsx
      Tempfile.create(['leadpulse-import', '.xlsx']) do |file|
        file.binmode
        file.write(@file_bytes)
        file.flush

        sheet = Roo::Spreadsheet.open(file.path, extension: :xlsx).sheet(0)
        headers = Array(sheet.row(1)).map { |value| normalize_header(value) }
        @headers = headers.reject(&:blank?)

        (2..sheet.last_row).map do |row_index|
          values = Array(sheet.row(row_index))
          headers.each_with_index.to_h { |header, index| [header, values[index]] }
        end
      end
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
        callback_contact_name: SupplierImports::ValueNormalizer.text(value_for(row_hash, :callback_contact_name))
      }
    end

    def build_record(normalized, logical_index)
      base = {
        external_id: normalized[:external_id].presence || logical_index.to_s,
        phone: normalized[:phone],
        email: normalized[:email].presence
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
      value.to_s.strip.downcase
    end

    def blank_row?(row)
      row.to_h.values.all? { |value| value.to_s.strip.blank? }
    end
  end
end
