require "caxlsx"

module Spreadsheets
  class SimpleXlsxBuilder
    DEFAULT_SHEET_NAME = "Planilha".freeze
    MIN_COLUMN_WIDTH = 12
    MAX_COLUMN_WIDTH = 42

    def initialize(sheet_name:, rows:)
      @sheet_name = sanitize_sheet_name(sheet_name)
      @rows = Array(rows).map { |row| Array(row) }
    end

    def call
      package = Axlsx::Package.new
      workbook = package.workbook
      header_style = workbook.styles.add_style(
        bg_color: "0F172A",
        fg_color: "FFFFFF",
        b: true,
        alignment: { vertical: :center, wrap_text: true }
      )
      body_style = workbook.styles.add_style(
        alignment: { vertical: :top, wrap_text: true }
      )

      workbook.add_worksheet(name: @sheet_name) do |sheet|
        @rows.each_with_index do |row, index|
          values = row.map { |value| value.nil? ? "" : value.to_s }
          style = index.zero? ? header_style : body_style
          sheet.add_row(
            values,
            types: Array.new(values.length, :string),
            style: Array.new(values.length, style)
          )
        end

        widths = column_widths
        sheet.column_widths(*widths) if widths.any?
      end

      package.to_stream.read
    end

    private

    def sanitize_sheet_name(sheet_name)
      sanitized = sheet_name.to_s.gsub(/[\\\/?*\[\]:]/, " ").squish.first(31)
      sanitized.presence || DEFAULT_SHEET_NAME
    end

    def column_widths
      return [] if @rows.empty?

      column_count = @rows.map(&:length).max.to_i
      Array.new(column_count) do |column_index|
        content_width = @rows.filter_map { |row| row[column_index]&.to_s&.length }.max.to_i + 2
        content_width.clamp(MIN_COLUMN_WIDTH, MAX_COLUMN_WIDTH)
      end
    end
  end
end
