require 'erb'
require 'zip'

module Spreadsheets
  class SimpleXlsxBuilder
    XML_DECLARATION = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'.freeze

    def initialize(sheet_name:, rows:)
      @sheet_name = sheet_name.to_s.first(31).presence || 'Planilha'
      @rows = Array(rows)
    end

    def call
      buffer = Zip::OutputStream.write_buffer do |zip|
        write_entry(zip, '[Content_Types].xml', content_types_xml)
        write_entry(zip, '_rels/.rels', root_rels_xml)
        write_entry(zip, 'xl/workbook.xml', workbook_xml)
        write_entry(zip, 'xl/_rels/workbook.xml.rels', workbook_rels_xml)
        write_entry(zip, 'xl/worksheets/sheet1.xml', worksheet_xml)
      end

      buffer.string
    end

    private

    def write_entry(zip, path, content)
      zip.put_next_entry(path)
      zip.write(content)
    end

    def content_types_xml
      <<~XML
        #{XML_DECLARATION}
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
      XML
    end

    def root_rels_xml
      <<~XML
        #{XML_DECLARATION}
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
      XML
    end

    def workbook_xml
      <<~XML
        #{XML_DECLARATION}
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="#{escape(@sheet_name)}" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
      XML
    end

    def workbook_rels_xml
      <<~XML
        #{XML_DECLARATION}
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
      XML
    end

    def worksheet_xml
      <<~XML
        #{XML_DECLARATION}
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            #{worksheet_rows_xml}
          </sheetData>
        </worksheet>
      XML
    end

    def worksheet_rows_xml
      @rows.map.with_index(1) do |row, row_index|
        cells = Array(row).map do |value|
          text = escape(value.to_s)
          %(<c t="inlineStr"><is><t xml:space="preserve">#{text}</t></is></c>)
        end.join

        %(<row r="#{row_index}">#{cells}</row>)
      end.join
    end

    def escape(value)
      ERB::Util.html_escape(value)
    end
  end
end
