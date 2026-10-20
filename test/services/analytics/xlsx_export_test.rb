require "test_helper"
require "zip"

module Analytics
  class XlsxExportTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @user = users(:one)
      attempts = [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 10), duration: 42) ]
      @batch = create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 10),
        created_at: brasilia(2026, 9, 20, 9, 55),
        records: [ analytics_record("confirmed", attempts: attempts, client_name: "=HYPERLINK(\"http://x\")", cnpj_original: "12.345.678/0001-95") ] +
          analytics_records(not_answered: 2)
      )
    end

    test "writes typed values, filters used, frozen headers and AutoFilter" do
      export = export_for(include_records: true)

      assert_equal "leadpulse_analytics_2026-09-25.xlsx", export[:filename]
      assert_equal [ "Resumo", "Lotes", "Chamadas por dia", "Registros" ], export[:sheets]

      with_workbook(export[:content]) do |workbook|
        assert_equal export[:sheets], workbook.sheets

        summary = workbook.sheet("Resumo")
        rows = (1..summary.last_row).map { |index| summary.row(index) }
        assert_includes rows, [ "Fluxo", "Todos os fluxos" ] + Array.new(rows.first.size - 2)
        assert_equal Date.new(2026, 8, 27), rows.find { |row| row.first == "Início" }[1]
        records_row = rows.find { |row| row[1] == "Registros" && row.first == "Visão geral" }
        assert_equal 3, records_row[2]
        confirmation = rows.find { |row| row[1] == "Taxa de confirmação" }
        assert_in_delta 1 / 3.0, confirmation[2], 0.0001
        assert_nil confirmation[6], "variação com baixa amostra não vai para a célula"
        assert_match "Baixa amostra", confirmation[7]

        batches = workbook.sheet("Lotes")
        assert_equal "Lote", batches.cell(1, 1)
        assert_equal @batch.display_code, batches.cell(2, 1)
        assert_kind_of DateTime, batches.cell(2, 5)
        assert_equal "20/09/2026 09:55", batches.cell(2, 5).strftime("%d/%m/%Y %H:%M")
        assert_equal 3, batches.cell(2, 9)
        assert_in_delta 1 / 3.0, batches.cell(2, 14), 0.0001
        assert_equal "Total", batches.cell(3, 1)

        records = workbook.sheet("Registros")
        assert_equal "=HYPERLINK(\"http://x\")", records.cell(2, 6)
        assert_nil records.formula(2, 6)
        assert_equal "12.345.678/0001-95", records.cell(2, 7)
        assert_equal 42, records.cell(2, 18)
      end

      xml = zip_entries(export[:content])["xl/worksheets/sheet2.xml"]
      assert_match(/<autoFilter ref=['"]A1:P2['"]/, xml, "AutoFilter só nas linhas de dados, sem a linha de totais")
      assert_match(/<pane [^>]*state=['"]frozen['"]/, xml)
      assert_includes xml, "<f>SUBTOTAL(109,I2:I2)</f>"
      assert_includes xml, "<f>IFERROR(SUBTOTAL(109,K2:K2)/(SUBTOTAL(109,L2:L2)),&quot;&quot;)</f>"
    end

    test "leaves the records sheet out for profiles without data export" do
      export = export_for(include_records: false)

      assert_equal [ "Resumo", "Lotes", "Chamadas por dia" ], export[:sheets]
    end

    test "never writes phones, transcripts or recordings" do
      content = export_for(include_records: true)[:content]
      all_xml = zip_entries(content).values.join

      assert_no_match(/\+55119|5511900000000|gravacao|texto|example\.test/, all_xml)
    end

    test "refuses more records than the sheet limit" do
      with_limit(2) do
        assert_raises(XlsxExport::TooManyRecords) { export_for(include_records: true) }
      end
    end

    private

    def export_for(include_records:)
      scope = analytics_scope(@account)
      report = Report.new(scope: scope, cache: ActiveSupport::Cache::NullStore.new)
      XlsxExport.new(report: report, scope: scope, user: @user, include_records: include_records, generated_at: brasilia(2026, 9, 25, 15)).call
    end

    def with_workbook(content)
      Tempfile.create([ "analytics", ".xlsx" ]) do |file|
        file.binmode
        file.write(content)
        file.flush
        yield Roo::Spreadsheet.open(file.path, extension: :xlsx)
      end
    end

    def zip_entries(content)
      Tempfile.create([ "analytics", ".xlsx" ]) do |file|
        file.binmode
        file.write(content)
        file.flush
        Zip::File.open(file.path) do |zip|
          zip.entries.select { |entry| entry.name.end_with?(".xml") }.to_h { |entry| [ entry.name, entry.get_input_stream.read ] }
        end
      end
    end

    def with_limit(limit)
      original = XlsxExport::RECORDS_LIMIT
      XlsxExport.send(:remove_const, :RECORDS_LIMIT)
      XlsxExport.const_set(:RECORDS_LIMIT, limit)
      yield
    ensure
      XlsxExport.send(:remove_const, :RECORDS_LIMIT)
      XlsxExport.const_set(:RECORDS_LIMIT, original)
    end
  end
end
