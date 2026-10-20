require "caxlsx"

module Analytics
  # Planilha do Analytics, a partir do mesmo relatório e dos mesmos filtros da tela.
  #
  # Valores tipados: contagens como inteiros, taxas como fração com formato de %, datas como
  # datas do Excel (horário de Brasília) e durações em segundos. Abas de dados com cabeçalho
  # congelado e AutoFilter; totais com SUBTOTAL, que continua certo com a planilha filtrada.
  # Nunca inclui telefone, e-mail, transcrição nem gravação. A aba Registros só entra para
  # quem pode exportar dados por registro.
  class XlsxExport
    include ActionView::Helpers::TranslationHelper

    CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze
    RECORDS_LIMIT = 50_000

    class TooManyRecords < StandardError; end

    SUMMARY_SECTIONS = [
      [ :overview, :summary, %i[records validation_rate confirmation_rate answer_rate median_duration batches] ],
      [ :calls, :summary, %i[attempts answered answer_rate median_duration average_duration duration_coverage] ],
      [ :qualification, :summary, %i[qualified qualification_rate opportunities collected] ],
      [ :qualification, :searches, %i[searches] ],
      [ :batches, :summary, %i[batches records invalid_rate median_wait median_processing p90_processing] ]
    ].freeze

    attr_reader :sheets

    def initialize(report:, scope:, user:, include_records:, generated_at: Time.current)
      @report = report
      @scope = scope
      @filters = scope.filters
      @user = user
      @include_records = include_records
      @generated_at = generated_at.in_time_zone(Sql::TIME_ZONE)
      @sheets = []
    end

    def filename
      "leadpulse_analytics_#{@generated_at.to_date.iso8601}.xlsx"
    end

    def call
      records = load_records if @include_records
      package = Axlsx::Package.new
      package.use_shared_strings = true
      @styles = build_styles(package.workbook)

      add_summary(package.workbook)
      add_batches(package.workbook)
      add_daily_calls(package.workbook)
      add_records(package.workbook, records) if records

      { filename: filename, content: package.to_stream.read, content_type: CONTENT_TYPE, sheets: @sheets }
    end

    private

    def load_records
      rows = RecordsQuery.new(@scope.validated_batches(@filters.window)).each_row.first(RECORDS_LIMIT + 1)
      raise TooManyRecords if rows.size > RECORDS_LIMIT

      rows
    end

    def build_styles(workbook)
      styles = workbook.styles
      border = { style: :thin, color: "D0D5DD", edges: [ :bottom ] }
      {
        title: styles.add_style(b: true, sz: 14),
        label: styles.add_style(b: true, fg_color: "475467"),
        header: styles.add_style(b: true, bg_color: "F2F4F7", border: border, alignment: { vertical: :center, wrap_text: true }),
        text: styles.add_style(alignment: { vertical: :top }),
        wrap: styles.add_style(alignment: { vertical: :top, wrap_text: true }),
        integer: styles.add_style(num_fmt: 3),
        decimal: styles.add_style(format_code: "0.0"),
        percent: styles.add_style(format_code: "0.0%"),
        points: styles.add_style(format_code: '+0.0" p.p.";-0.0" p.p.";0.0" p.p."'),
        signed_percent: styles.add_style(format_code: "+0.0%;-0.0%;0.0%"),
        seconds: styles.add_style(format_code: "#,##0"),
        signed_seconds: styles.add_style(format_code: "+#,##0;-#,##0;0"),
        date: styles.add_style(format_code: "dd/mm/yyyy"),
        datetime: styles.add_style(format_code: "dd/mm/yyyy hh:mm"),
        total: styles.add_style(b: true, num_fmt: 3, border: { style: :thin, color: "D0D5DD", edges: [ :top ] }),
        total_percent: styles.add_style(b: true, format_code: "0.0%", border: { style: :thin, color: "D0D5DD", edges: [ :top ] }),
        total_label: styles.add_style(b: true, border: { style: :thin, color: "D0D5DD", edges: [ :top ] })
      }
    end

    # Resumo: filtros usados, quem gerou, e a tabela de indicadores com atual, anterior e n.
    def add_summary(workbook)
      @sheets << "Resumo"
      workbook.add_worksheet(name: "Resumo") do |sheet|
        sheet.add_row [ "LeadPulse — Analytics" ], style: @styles[:title]
        sheet.add_row []
        info_rows.each do |label, value, style|
          sheet.add_row [ label, value ], style: [ @styles[:label], style || @styles[:text] ], types: [ :string, (style ? nil : :string) ]
        end
        sheet.add_row []

        header = [ "Seção", "Indicador", "Atual", "n", "Anterior", "n anterior", "Variação", "Observação", "Definição" ]
        header_row = sheet.add_row(header, style: @styles[:header])
        first_row = header_row.row_index + 1
        indicator_rows.each { |row| sheet.add_row(row[:values], style: row[:styles], types: row[:types]) }
        last_row = [ sheet.rows.size, first_row ].max
        sheet.auto_filter = "A#{first_row}:I#{last_row}"
        sheet.column_widths(22, 30, 12, 10, 12, 10, 14, 34, 60)
      end
    end

    def info_rows
      previous = @filters.previous_window
      [
        [ "Empresa", @scope.account.name ],
        [ "Período", @filters.window.label ],
        [ "Início", @filters.window.first_day, @styles[:date] ],
        [ "Fim", @filters.window.last_day, @styles[:date] ],
        [ "Comparação", t("analytics.filters.comparisons.#{@filters.comparison}") ],
        [ "Período de comparação", previous ? previous.label : "—" ],
        [ "Fluxo", @filters.workflow_kind ? SupplierImport::WORKFLOW_KIND_LABELS.fetch(@filters.workflow_kind) : t("analytics.filters.all_workflows") ],
        [ "Origem", @filters.source ? SupplierImport::SOURCE_LABELS.fetch(@filters.source) : t("analytics.filters.all_sources") ],
        [ "Lote", @filters.supplier_import_id ? SupplierImport.display_code_for(@filters.supplier_import_id) : t("analytics.filters.all_batches") ],
        [ "Status do lote (aba Lotes)", @filters.status ? I18n.t("shared.statuses.#{@filters.status}", default: @filters.status) : t("analytics.filters.all_statuses") ],
        [ "Referência de data", "Visão geral e Qualificação: início da validação do lote. Chamadas: horário de cada tentativa. Lotes: criação do lote." ],
        [ "Gerado em", @generated_at, @styles[:datetime] ],
        [ "Gerado por", @user.name ]
      ]
    end

    def indicator_rows
      SUMMARY_SECTIONS.flat_map do |page_name, section_name, keys|
        section = @report.public_send(page_name)[section_name]
        section_label = t("analytics.tabs.#{page_name}")

        keys.map do |key|
          label = t("analytics.kpis.#{page_name}.#{key}.label")
          definition = t("analytics.kpis.#{page_name}.#{key}.hint")
          if section.failed?
            next { values: [ section_label, label, nil, nil, nil, nil, nil, "Não foi possível calcular", definition ], styles: @styles[:wrap], types: Array.new(9, :string) }
          end

          indicator_row(section_label, label, definition, section.data[:metrics].fetch(key))
        end
      end
    end

    def indicator_row(section_label, label, definition, comparison)
      current = comparison.current
      previous = comparison.previous
      value_style = { count: @styles[:integer], rate: @styles[:percent], duration: @styles[:seconds] }.fetch(current.kind, @styles[:decimal])
      label = "#{label} (s)" if current.kind == :duration

      delta, delta_style = conclusive_delta(comparison)
      values = [
        section_label, label, current.value, current.sample,
        previous&.value, previous&.sample, delta, observation(comparison), definition
      ]
      styles = [ @styles[:text], @styles[:text], value_style, @styles[:integer], value_style, @styles[:integer], delta_style || @styles[:text], @styles[:wrap], @styles[:wrap] ]
      types = [ :string, :string, nil, :integer, nil, nil, nil, :string, :string ]

      { values: values, styles: styles, types: types }
    end

    # Só a variação conclusiva vai para a célula; com baixa amostra a célula fica vazia e a
    # observação explica.
    def conclusive_delta(comparison)
      return [ nil, nil ] unless comparison.conclusive?

      case comparison.current.kind
      when :count then [ comparison.delta, @styles[:signed_percent] ]
      when :rate then [ comparison.delta * 100, @styles[:points] ]
      when :duration then [ comparison.delta, @styles[:signed_seconds] ]
      else [ comparison.delta, @styles[:decimal] ]
      end
    end

    def observation(comparison)
      notes = []
      notes << "Baixa amostra (n < #{Metric::MIN_SAMPLE})" if comparison.current.kind != :count && comparison.current.low_sample?
      case comparison.status
      when :low_sample then notes << "variação não conclusiva"
      when :no_base then notes << "sem base anterior"
      end
      notes.join("; ").upcase_first
    end

    def add_batches(workbook)
      rows = BatchesQuery.new(@scope.created_batches(@filters.window)).rows(sort: @filters.sort, direction: @filters.direction)
      header = [
        "Lote", "Fluxo", "Origem", "Status", "Criado em", "Iniciado em", "Linhas importadas", "Linhas inválidas",
        "Registros", "Validados", "Confirmados", "Com resultado final", "Não atendidos", "Taxa de confirmação",
        "Tempo até o início (s)", "Processamento (s)"
      ]

      data_sheet(workbook, "Lotes", header, widths: [ 10, 12, 12, 13, 17, 17, 10, 10, 10, 10, 11, 11, 11, 12, 12, 12 ]) do |sheet|
        rows.each do |row|
          sheet.add_row(
            [
              SupplierImport.display_code_for(row[:id]),
              SupplierImport::WORKFLOW_KIND_LABELS.fetch(row[:workflow_kind], row[:workflow_kind]),
              SupplierImport::SOURCE_LABELS.fetch(row[:source], row[:source]),
              I18n.t("shared.statuses.#{row[:status]}", default: row[:status].to_s),
              local_time(row[:created_at]), local_time(row[:validation_started_at]),
              row[:total_rows], row[:invalid_rows], row[:records], row[:validated], row[:confirmed], row[:terminal], row[:not_answered],
              (row[:confirmed].to_f / row[:terminal] if row[:terminal].positive?),
              row[:wait_seconds]&.round, row[:processing_seconds]&.round
            ],
            types: [ :string, :string, :string, :string, :time, :time, :integer, :integer, :integer, :integer, :integer, :integer, :integer, :float, :integer, :integer ],
            style: [ nil, nil, nil, nil, @styles[:datetime], @styles[:datetime] ] + Array.new(7, @styles[:integer]) + [ @styles[:percent], @styles[:seconds], @styles[:seconds] ]
          )
        end

        totals_row(sheet, rows.size, columns: 16, sums: %w[G H I J K L M], rate_column: "N", numerator: "K", denominators: %w[L])
      end
    end

    def add_daily_calls(workbook)
      rows = AttemptsQuery.new(@scope.attempt_batches(@filters.window), @filters.window).daily(Filters::GROUPING_DAY)
      header = [ "Dia", "Tentativas", "Atendidas", "Não atendidas", "Falhas", "Outros status", "Taxa de atendimento", "Atendidas com duração", "Duração mediana (s)" ]

      data_sheet(workbook, "Chamadas por dia", header, widths: [ 12, 11, 11, 13, 9, 12, 13, 14, 14 ]) do |sheet|
        rows.each do |row|
          sheet.add_row(
            [
              row[:date], row[:attempts], row[:answered], row[:not_answered], row[:failed], row[:other],
              (row[:answered].to_f / row[:answer_base] if row[:answer_base].positive?),
              row[:with_duration], row[:median_duration]&.round
            ],
            types: [ :date, :integer, :integer, :integer, :integer, :integer, :float, :integer, :integer ],
            style: [ @styles[:date] ] + Array.new(5, @styles[:integer]) + [ @styles[:percent], @styles[:integer], @styles[:seconds] ]
          )
        end

        totals_row(sheet, rows.size, columns: 9, sums: %w[B C D E F H], rate_column: "G", numerator: "C", denominators: %w[C D E])
      end
    end

    def add_records(workbook, rows)
      header = [
        "Lote", "Fluxo", "Origem", "Iniciado em", "Registro", "Fornecedor", "CNPJ", "Segmento", "Status final",
        "Resultado da chamada", "Status da chamada", "Qualificação", "Telefone é da empresa", "Fornece o segmento",
        "Interesse comercial", "Tentativas", "Última tentativa em", "Duração atendida (s)", "Recusa LGPD"
      ]

      data_sheet(workbook, "Registros", header, widths: [ 10, 12, 12, 17, 10, 32, 20, 18, 16, 18, 16, 22, 12, 12, 12, 10, 17, 12, 10 ]) do |sheet|
        rows.each do |row|
          sheet.add_row(
            [
              SupplierImport.display_code_for(row[:batch_id]),
              SupplierImport::WORKFLOW_KIND_LABELS.fetch(row[:workflow_kind], row[:workflow_kind]),
              SupplierImport::SOURCE_LABELS.fetch(row[:source], row[:source]),
              local_time(row[:validation_started_at]),
              row[:external_id], row[:company_name], row[:cnpj], row[:segment_name],
              code_label("final_statuses", row[:final_status]),
              code_label("results", row[:call_result]),
              code_label("call_statuses", row[:call_status]),
              code_label("outcomes", row[:qualification_outcome]),
              yes_no(row[:phone_belongs_to_company]), yes_no(row[:supplies_segment]), yes_no(row[:commercial_interest]),
              row[:attempts_count], local_time(row[:last_attempt_at]), row[:answered_duration_seconds]&.round,
              yes_no(row[:privacy_refusal_detected])
            ],
            types: Array.new(3, :string) + [ :time ] + Array.new(11, :string) + [ :integer, :time, :integer, :string ],
            style: Array.new(3, nil) + [ @styles[:datetime] ] + Array.new(11, nil) + [ @styles[:integer], @styles[:datetime], @styles[:seconds], nil ]
          )
        end
      end
    end

    def data_sheet(workbook, name, header, widths:)
      @sheets << name
      workbook.add_worksheet(name: name) do |sheet|
        sheet.add_row(header, style: @styles[:header])
        yield sheet
        data_rows = sheet.rows.size - (sheet.rows.last&.cells&.first&.value == "Total" ? 1 : 0)
        last_column = Axlsx.col_ref(header.size - 1)
        sheet.auto_filter = "A1:#{last_column}#{[ data_rows, 1 ].max}"
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = "A2"
          pane.state = :frozen
          pane.y_split = 1
          pane.active_pane = :bottom_left
        end
        sheet.column_widths(*widths)
      end
    end

    # Linha de totais fora do AutoFilter. Somas com SUBTOTAL(109), que respeita o filtro, e a
    # taxa como razão das somas, nunca média de taxas.
    def totals_row(sheet, count, columns:, sums:, rate_column:, numerator:, denominators:)
      return if count.zero?

      last = count + 1
      subtotal = ->(column) { "SUBTOTAL(109,#{column}2:#{column}#{last})" }
      index = ->(column) { Axlsx.name_to_indices("#{column}1").first }

      values = Array.new(columns)
      values[0] = "Total"
      sums.each { |column| values[index.call(column)] = "=#{subtotal.call(column)}" }
      values[index.call(rate_column)] = "=IFERROR(#{subtotal.call(numerator)}/(#{denominators.map(&subtotal).join('+')}),\"\")"

      styles = Array.new(columns, @styles[:total])
      styles[0] = @styles[:total_label]
      styles[index.call(rate_column)] = @styles[:total_percent]
      sheet.add_row(values, style: styles, escape_formulas: false)
    end

    def local_time(time)
      time&.in_time_zone(Sql::TIME_ZONE)
    end

    def code_label(scope, code)
      return if code.blank?

      t("analytics.#{scope}.#{code}", default: code.to_s)
    end

    def yes_no(value)
      return if value.nil?

      value ? "Sim" : "Não"
    end
  end
end
