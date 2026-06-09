require 'csv'

module SupplierImports
  class ExportResultXlsxService
    class Error < StandardError; end

    CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

    def initialize(supplier_import:)
      @supplier_import = supplier_import
    end

    def call
      csv_export = SupplierImports::ExportResultCsvService.new(supplier_import: @supplier_import).call
      csv = CSV.parse(csv_export[:content], headers: true)
      rows = [csv.headers] + csv.map { |row| csv.headers.map { |header| row[header] } }

      {
        filename: @supplier_import.export_xlsx_filename,
        content: Spreadsheets::SimpleXlsxBuilder.new(sheet_name: 'Resultado', rows: rows).call,
        content_type: CONTENT_TYPE
      }
    rescue SupplierImports::ExportResultCsvService::Error => e
      raise Error, e.message
    end
  end
end
