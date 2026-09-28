module AnalyticsHelper
  NUMBER_FORMAT = { delimiter: ".", separator: "," }.freeze
  MINUS = "−".freeze

  # Sentido desejável de cada métrica. Define só a cor da variação; o que não está aqui
  # (volumes, durações de chamada) fica neutro.
  METRIC_POLARITY = {
    validation_rate: :up,
    confirmation_rate: :up,
    answer_rate: :up,
    qualification_rate: :up,
    duration_coverage: :up,
    invalid_rate: :down,
    median_wait: :down,
    median_processing: :down,
    p90_processing: :down
  }.freeze

  ATTEMPT_STATUSES = %w[answered not_answered failed other].freeze
  STATUS_CHART_TONES = { "answered" => "confirmed", "not_answered" => "not_answered", "failed" => "rejected", "other" => "other" }.freeze
  OUTCOME_CHART_TONES = {
    "qualified_supplier" => "confirmed",
    "does_not_supply_segment" => "rejected",
    "not_interested" => "rejected",
    "wrong_company" => "rejected",
    "privacy_refusal" => "rejected",
    "inconclusive" => "inconclusive",
    "not_answered" => "not_answered"
  }.freeze

  # Tom de cada resultado nos gráficos (tokens --lp-chart-*).
  RESULT_CHART_TONES = {
    "confirmed" => "confirmed",
    "rejected" => "rejected",
    "inconclusive" => "inconclusive",
    "not_answered" => "not_answered",
    "pending_dispatch" => "other",
    "other" => "other"
  }.freeze

  # O status do lote só existe na página Lotes; as outras abas não o carregam.
  def analytics_tabs
    params = @filters.to_params.except(:status)
    [
      [ :overview, analytics_path(params) ],
      [ :calls, calls_analytics_path(params) ],
      [ :qualification, qualification_analytics_path(params) ],
      [ :batches, batches_analytics_path(@filters.to_params) ]
    ]
  end

  def analytics_count(value)
    number_with_delimiter(value.to_i, **NUMBER_FORMAT)
  end

  def analytics_percent(fraction, precision: 1)
    return "—" if fraction.nil?

    number_to_percentage(fraction * 100, precision: precision, **NUMBER_FORMAT)
  end

  def analytics_decimal(value, precision: 1)
    return "—" if value.nil?

    number_with_precision(value, precision: precision, **NUMBER_FORMAT)
  end

  # 8 s · 2 min 07 s · 3 h 20 min · 4 d 3 h
  def analytics_duration(seconds)
    return "—" if seconds.nil?

    seconds = seconds.to_f.round
    return "#{seconds} s" if seconds < 60

    minutes, secs = seconds.divmod(60)
    return format("%d min %02d s", minutes, secs) if minutes < 60

    hours, mins = minutes.divmod(60)
    return format("%d h %02d min", hours, mins) if hours < 24

    days, hrs = hours.divmod(24)
    format("%d d %d h", days, hrs)
  end

  def analytics_metric_value(metric)
    case metric.kind
    when :count then analytics_count(metric.value)
    when :rate then analytics_percent(metric.value)
    when :duration then analytics_duration(metric.value)
    else analytics_decimal(metric.value)
    end
  end

  # Célula da faixa de KPIs. Hierarquia: valor; n com ⓘ de baixa amostra (o valor anterior
  # fica no tooltip do ⓘ); variação só quando a comparação é conclusiva. Nenhuma métrica é
  # escondida por amostra pequena.
  def analytics_kpi(key, comparison, page:, link: nil)
    comparison = Analytics::Comparison.new(current: comparison, previous: nil) if comparison.is_a?(Analytics::Metric)
    metric = comparison.current
    hint = t("analytics.kpis.#{page}.#{key}.hint")
    value = analytics_metric_value(metric)
    value = link_to(value, link, class: "analytics-drill-link", data: { turbo_frame: "analytics_content", turbo_action: "advance" }) if link

    content_tag(:div, class: "workspace-metric-card analytics-kpi", data: { metric: key }) do
      safe_join([
        content_tag(:p, class: "workspace-metric-card__label") do
          safe_join([
            content_tag(:span, t("analytics.kpis.#{page}.#{key}.label")),
            content_tag(:i, "", class: "fa-solid fa-circle-info analytics-kpi__hint", title: hint, role: "img", aria: { label: hint })
          ])
        end,
        content_tag(:p, value, class: "workspace-metric-card__value"),
        analytics_sample(metric, comparison),
        analytics_comparison(key, comparison)
      ].compact)
    end
  end

  def analytics_sample(metric, comparison = nil)
    return if metric.kind == :count

    content_tag(:p, class: "analytics-kpi__sample") do
      safe_join([
        content_tag(:span, t("analytics.metric.sample", count: analytics_count(metric.sample))),
        (analytics_low_sample_flag(sample: metric.sample, previous: comparison&.previous) if metric.low_sample?)
      ].compact, " ")
    end
  end

  # Marca discreta de baixa amostra: ícone com texto para leitor de tela e tooltip.
  def analytics_low_sample_flag(sample:, previous: nil)
    text = t("analytics.metric.low_sample_hint", count: analytics_count(sample))
    if previous&.available?
      shown = analytics_metric_value(previous)
      shown += " (#{t('analytics.metric.sample', count: analytics_count(previous.sample))})" unless previous.kind == :count
      text += " #{t('analytics.metric.previous', value: shown)}."
    end
    content_tag(:span, class: "analytics-low-sample", role: "img", title: text, aria: { label: text }) do
      content_tag(:i, "", class: "fa-solid fa-circle-info", aria: { hidden: true })
    end
  end

  # Variação só quando conclusiva (amostra suficiente nos dois lados e base anterior).
  def analytics_comparison(key, comparison)
    analytics_delta(key, comparison) if comparison.status == :ok
  end

  def analytics_delta(key, comparison)
    delta = comparison.delta
    direction = if delta.abs < 1e-9 then :flat elsif delta.positive? then :up else :down end
    polarity = METRIC_POLARITY.fetch(key, :neutral)
    tone = if direction == :flat || polarity == :neutral then :neutral elsif direction == polarity then :good else :bad end
    icon = { up: "fa-arrow-up", down: "fa-arrow-down", flat: "fa-arrow-right" }.fetch(direction)
    reader = { up: "analytics.metric.increase", down: "analytics.metric.decrease", flat: "analytics.metric.unchanged" }.fetch(direction)

    content_tag(:p, class: "analytics-delta analytics-delta--#{tone}") do
      safe_join([
        content_tag(:i, "", class: "fa-solid #{icon}", aria: { hidden: true }),
        content_tag(:span, t(reader), class: "sr-only"),
        content_tag(:span, analytics_delta_value(comparison.current.kind, delta), class: "analytics-delta__value"),
        content_tag(:span, t("analytics.metric.compared_to", window: @filters.previous_window.label), class: "analytics-delta__context")
      ])
    end
  end

  def analytics_delta_value(kind, delta)
    sign = delta.negative? ? MINUS : "+"
    magnitude = delta.abs
    case kind
    when :count then "#{sign}#{analytics_percent(magnitude)}"
    when :rate then "#{sign}#{analytics_decimal(magnitude * 100)} p.p."
    when :duration then "#{sign}#{analytics_duration(magnitude)}"
    else "#{sign}#{analytics_decimal(magnitude)}"
    end
  end

  def analytics_section_error
    content_tag(:div, class: "workspace-callout analytics-section-error", role: "status") do
      safe_join([
        workspace_icon(:warning, classes: "text-warning-fg"),
        content_tag(:p, t("analytics.section_error"))
      ])
    end
  end

  EVOLUTION_RESULTS = %w[confirmed rejected inconclusive not_answered other].freeze

  # Cada gráfico devolve a tabela de dados (versão acessível, sempre no documento) e os dados
  # do ECharts, calculados juntos para que os dois mostrem exatamente os mesmos números.
  def analytics_evolution_chart(data)
    series = EVOLUTION_RESULTS.map do |code|
      { name: analytics_result_label(code), tone: code, code: code, values: data[:rows].map { |row| row[code.to_sym] } }
    end
    previous = data[:previous_totals] && { name: t("analytics.sections.evolution_previous"), values: data[:previous_totals] }
    extras = data[:rows].map do |row|
      rate = Analytics::Metric.rate(row[:confirmed], Analytics::Query::TERMINAL_RESULTS.sum { |code| row[code.to_sym] })
      [ [ t("analytics.kpis.overview.confirmation_rate.label"), analytics_rate_text(rate) ] ]
    end

    analytics_stacked_chart(data, series: series, totals: data[:rows].map { |row| row[:records] }, previous: previous,
      unit: "registros", extras: extras, drill: analytics_drill(:records, "resultado"))
  end

  def analytics_attempts_timeline_chart(data)
    series = ATTEMPT_STATUSES.map do |status|
      { name: t("analytics.statuses.#{status}"), tone: STATUS_CHART_TONES.fetch(status), code: status, values: data[:rows].map { |row| row[status.to_sym] } }
    end
    extras = data[:rows].map do |row|
      [ [ t("analytics.kpis.calls.answer_rate.label"), analytics_rate_text(Analytics::Metric.rate(row[:answered], row[:answer_base])) ] ]
    end

    analytics_stacked_chart(data, series: series, totals: data[:rows].map { |row| row[:attempts] }, unit: "tentativas",
      extras: extras, drill: analytics_drill(:attempts, "status"))
  end

  # Colunas empilhadas por dia, semana ou mês. O tooltip recebe tudo pronto do servidor:
  # período por extenso, valores, taxa com n e diferença para a janela de comparação.
  def analytics_stacked_chart(data, series:, totals:, unit:, previous: nil, extras: nil, drill: nil)
    labels = data[:rows].map { |row| analytics_bucket_label(row[:date], data[:grouping]) }
    long_labels = data[:rows].map { |row| analytics_bucket_long_label(row[:date], data[:grouping]) }
    ranges = data[:rows].map { |row| @filters.window.bucket_range(row[:date], data[:grouping]).map(&:iso8601) }
    differences = previous && totals.each_with_index.map do |total, index|
      before = previous[:values][index]
      next if before.nil?

      delta = total - before
      "#{delta.positive? ? '+' : (delta.negative? ? MINUS : '')}#{analytics_count(delta.abs)} #{delta.abs == 1 ? unit.delete_suffix('s') : unit}"
    end

    head = [ t("analytics.chart.period") ] + series.map { |item| item[:name] } + [ t("analytics.chart.total") ]
    head << previous[:name] if previous
    rows = long_labels.each_with_index.map do |label, index|
      cells = [ label ] + series.map { |item| analytics_count(item[:values][index]) } + [ analytics_count(totals[index]) ]
      cells << analytics_count(previous[:values][index]) if previous
      cells
    end
    parts = series.filter_map { |item| "#{item[:name]}: #{analytics_count(item[:values].sum)}" if item[:values].sum.positive? }

    {
      head: head,
      rows: rows,
      chart: {
        kind: "stacked_timeline",
        height: 280,
        data: {
          labels: labels, longLabels: long_labels, series: series, previous: previous, totalLabel: t("analytics.chart.total"),
          extras: extras, differences: differences, differenceLabel: t("analytics.chart.vs_previous"),
          drill: drill && drill.merge(ranges: ranges)
        },
        summary: "#{analytics_count(totals.sum)} #{unit} em #{@filters.window.label}. #{parts.join('; ')}."
      }
    }
  end

  # Drill-down só para quem pode ver os registros (mesma regra do detalhe do lote).
  def analytics_drill?
    current_membership&.can_view_evidence?
  end

  # Base do drill-down para o JavaScript: URL com os filtros atuais e o nome do parâmetro
  # que recebe o código da série/barra clicada. Sem permissão, não há drill-down.
  def analytics_drill(kind, param)
    return unless analytics_drill?

    { base: analytics_drill_path(kind, {}), param: param }
  end

  def analytics_drill_path(kind, extra = {})
    params = @filters.to_params.except(:agrupar, :status).merge(extra)
    kind == :attempts ? attempts_analytics_path(params) : records_analytics_path(params)
  end

  # Filtros secundários ativos como chips removíveis; a URL continua sendo a fonte.
  def analytics_active_filter_chips
    base = @filters.to_params.merge(@drill ? @drill[:params].symbolize_keys : {})
    chips = []
    chips << [ t("analytics.filters.source"), SupplierImport::SOURCE_LABELS.fetch(@filters.source), :origem ] if @filters.source
    chips << [ t("analytics.filters.batch"), analytics_batch_code(@filters.supplier_import_id), :lote ] if @filters.supplier_import_id
    chips << [ t("analytics.filters.status"), local_status_label(@filters.status), :status ] if @filters.status && action_name == "batches"
    chips.map { |label, shown, key| [ label, shown, url_for(base.except(key)) ] }
  end

  # Critérios do drill-down em linguagem da tela, cada um com o link que o remove.
  def analytics_drill_criteria(kind)
    @drill[:params].map do |name, value|
      label, shown = case name
      when "resultado" then [ t("analytics.drill.criteria.result"), analytics_result_label(value == "outros" ? "other" : value) ]
      when "ligacao" then [ t("analytics.drill.criteria.call"), t("analytics.drill.calls.#{value}") ]
      when "qualificacao" then [ t("analytics.drill.criteria.outcome"), analytics_outcome_label(value) ]
      when "status" then [ t("analytics.drill.criteria.status"), t("analytics.statuses.#{value == 'outros' ? 'other' : value}") ]
      when "dia_semana" then [ t("analytics.drill.criteria.weekday"), I18n.t("date.day_names")[value.to_i % 7].capitalize ]
      when "hora" then [ t("analytics.drill.criteria.hour"), t("analytics.hour_range", from: format("%02d", value.to_i), to: format("%02d", (value.to_i + 1) % 24)) ]
      when "duracao" then [ t("analytics.drill.criteria.duration"), t("analytics.duration_bins.#{value}") ]
      end
      remaining = @drill[:params].except(name)
      [ label, shown, analytics_drill_path(kind, remaining) ]
    end
  end

  def analytics_drill_back_path(kind)
    params = @filters.to_params.except(:status)
    return calls_analytics_path(params) if kind == :attempts
    return qualification_analytics_path(params) if @drill[:params].key?("qualificacao")

    analytics_path(params)
  end

  def analytics_drill_next_path(kind, cursor)
    return unless cursor

    analytics_drill_path(kind, @drill[:params].merge(pagina: Base64.urlsafe_encode64(JSON.generate(cursor), padding: false)))
  end

  def analytics_drill_link(label, kind, extra = {})
    return label unless analytics_drill?

    link_to(label, analytics_drill_path(kind, extra), class: "analytics-drill-link", data: { turbo_frame: "analytics_content", turbo_action: "advance" })
  end

  # Mapa de calor dia da semana × hora (horário de Brasília). Cada célula leva tentativas,
  # atendidas e a taxa com n, já formatada; o JavaScript só escolhe a medida exibida.
  def analytics_heatmap_chart(cells)
    days = (1..7).map { |weekday| I18n.t("date.abbr_day_names")[weekday % 7].capitalize }
    day_names = (1..7).map { |weekday| I18n.t("date.day_names")[weekday % 7].capitalize }
    hours = (0..23).map { |hour| t("analytics.hour", hour: hour) }
    hour_names = (0..23).map { |hour| t("analytics.hour_range", from: format("%02d", hour), to: format("%02d", (hour + 1) % 24)) }
    metrics = cells.map { |cell| Analytics::Metric.rate(cell[:answered], cell[:answer_base]) }
    links = (cells.map { |cell| analytics_drill_path(:attempts, dia_semana: cell[:weekday], hora: cell[:hour]) } if analytics_drill?)
    busiest = cells.max_by { |cell| cell[:attempts] }

    {
      head: [ t("analytics.table.weekday"), t("analytics.table.hour"), t("analytics.table.attempts"), t("analytics.table.answered"), t("analytics.table.answer_rate") ],
      rows: cells.each_with_index.map do |cell, index|
        label = "#{day_names[cell[:weekday] - 1]}"
        label = link_to(label, links[index], class: "analytics-drill-link", data: { turbo_frame: "analytics_content", turbo_action: "advance" }) if links
        [ label, hour_names[cell[:hour]], analytics_count(cell[:attempts]), analytics_count(cell[:answered]), analytics_rate_text(metrics[index]) ]
      end,
      chart: {
        kind: "heatmap",
        height: 300,
        data: {
          days: days, dayNames: day_names, hours: hours, hourNames: hour_names,
          cells: cells.each_with_index.map do |cell, index|
            [ cell[:hour], cell[:weekday] - 1, cell[:attempts], cell[:answered], metrics[index].value&.round(4), metrics[index].low_sample?, analytics_rate_text(metrics[index]) ]
          end,
          links: links,
          labels: { attempts: t("analytics.table.attempts"), answered: t("analytics.table.answered"), rate: t("analytics.table.answer_rate") }
        },
        summary: busiest ? t("analytics.chart.summary.heatmap", day: day_names[busiest[:weekday] - 1], hour: hour_names[busiest[:hour]], count: analytics_count(busiest[:attempts]), cells: cells.size) : t("analytics.empty_calls")
      }
    }
  end

  def analytics_rate_text(metric)
    parts = [ analytics_percent(metric.value), t("analytics.metric.sample", count: analytics_count(metric.sample)) ]
    parts << t("analytics.metric.low_sample") if metric.available? && metric.low_sample?
    parts.join(" · ")
  end

  def analytics_outcome_label(code)
    t("analytics.outcomes.#{code}", default: t("analytics.outcomes.other"))
  end

  def analytics_outcomes_chart(title, counts)
    analytics_distribution_chart(title, counts, label: method(:analytics_outcome_label), tone: ->(code) { OUTCOME_CHART_TONES.fetch(code, "other") },
      drill: [ :records, "qualificacao" ])
  end

  # Cabeçalho ordenável da tabela de lotes: alterna a direção e anuncia a ordem atual.
  def analytics_sort_header(label, key, page, numeric: true)
    active = page.sort == key
    direction = active && page.direction == "desc" ? "asc" : "desc"
    icon = if active then page.direction == "asc" ? "fa-arrow-up" : "fa-arrow-down" else "fa-sort" end

    content_tag(:th, scope: "col", class: workspace_class_names(("is-numeric" if numeric), "analytics-sortable"), aria: { sort: (active ? (page.direction == "asc" ? "ascending" : "descending") : nil) }) do
      link_to url_for(@filters.to_params.merge(ordem: key, direcao: direction)),
        class: workspace_class_names("analytics-sort", ("analytics-sort--active" if active)),
        aria: { label: t("analytics.table.sort", column: label) } do
        safe_join([ content_tag(:span, label), content_tag(:i, "", class: "fa-solid #{icon}", aria: { hidden: true }) ])
      end
    end
  end

  # Barras horizontais em ordem de volume. drill: [:records|:attempts, parâmetro]; o código
  # "other" vira "outros" na URL.
  def analytics_distribution_chart(title, counts, label: method(:analytics_result_label), tone: ->(code) { RESULT_CHART_TONES.fetch(code, "other") },
                                   value_label: t("analytics.table.records"), drill: nil)
    total = counts.values.sum
    items = counts.reject { |_, count| count.zero? }.sort_by { |_, count| -count }
    labels = items.map { |code, _| label.call(code) }
    shares = items.map { |_, count| analytics_percent(total.positive? ? count.to_f / total : nil) }
    links = (items.map { |code, _| analytics_drill_path(drill[0], drill[1] => analytics_drill_code(code)) } if drill && analytics_drill?)

    {
      head: [ title, value_label, t("analytics.chart.share") ],
      rows: items.each_with_index.map do |(code, count), index|
        name = drill ? analytics_drill_link(labels[index], drill[0], drill[1] => analytics_drill_code(code)) : labels[index]
        [ name, analytics_count(count), shares[index] ]
      end,
      chart: {
        kind: "ranked_bars",
        height: analytics_bar_chart_height(items.size),
        data: {
          labels: labels,
          values: items.map(&:last),
          tones: items.map { |code, _| tone.call(code) },
          shares: shares,
          total: analytics_count(total),
          valueLabel: value_label,
          shareLabel: t("analytics.chart.share_of", total: analytics_count(total)),
          links: links
        },
        summary: "#{title}. " + items.each_with_index.map { |(_, count), index| "#{labels[index]}: #{analytics_count(count)} (#{shares[index]})" }.join("; ")
      }
    }
  end

  # Histograma do tempo de processamento dos lotes (faixas de BatchesQuery::PROCESSING_BINS).
  def analytics_processing_histogram(bins, median:, p90:)
    measured = bins.sum(&:last)
    labels = bins.map { |key, _| t("analytics.processing_bins.#{key}") }
    shares = bins.map { |_, count| analytics_percent(measured.positive? ? count.to_f / measured : nil) }

    {
      head: [ t("analytics.table.processing"), t("analytics.table.batches"), t("analytics.chart.share") ],
      rows: bins.each_with_index.map { |(_, count), index| [ labels[index], analytics_count(count), shares[index] ] },
      note: t("analytics.processing_distribution_note", median: analytics_duration(median.value), p90: analytics_duration(p90.value), count: analytics_count(median.sample)),
      chart: {
        kind: "histogram",
        height: 240,
        data: {
          labels: labels, longLabels: labels.map { |label| "#{t('analytics.table.processing')}: #{label}" }, values: bins.map(&:last), shares: shares,
          valueLabel: t("analytics.table.batches"), shareLabel: t("analytics.chart.share_of", total: analytics_count(measured))
        },
        summary: "#{t('analytics.sections.processing_distribution')}. " + bins.each_with_index.map { |(_, count), index| "#{labels[index]}: #{analytics_count(count)}" }.join("; ")
      }
    }
  end

  # Distribuição das durações informadas para chamadas atendidas. O histograma só é renderizado
  # quando existe cobertura e cada faixa leva às tentativas que a compõem.
  def analytics_duration_histogram(bins, median:, p90:, coverage:)
    measured = bins.sum(&:last)
    labels = bins.map { |key, _| t("analytics.duration_bins.#{key}") }
    shares = bins.map { |_, count| analytics_percent(measured.positive? ? count.to_f / measured : nil) }
    links = (bins.map { |key, _| analytics_drill_path(:attempts, duracao: key) } if analytics_drill?)

    {
      head: [ t("analytics.table.duration"), t("analytics.table.calls"), t("analytics.chart.share") ],
      rows: bins.each_with_index.map do |(key, count), index|
        label = analytics_drill_link(labels[index], :attempts, duracao: key)
        [ label, analytics_count(count), shares[index] ]
      end,
      note: t("analytics.duration_distribution_note", median: analytics_duration(median.value), p90: analytics_duration(p90.value),
        count: measured, formatted: analytics_count(measured), coverage: analytics_percent(coverage.value)),
      chart: {
        kind: "histogram",
        height: 240,
        data: {
          labels: labels, longLabels: labels.map { |label| "#{t('analytics.table.duration')}: #{label}" }, values: bins.map(&:last), shares: shares,
          valueLabel: t("analytics.table.calls"), shareLabel: t("analytics.chart.share_of", total: analytics_count(measured)), links: links
        },
        summary: "#{t('analytics.sections.duration_distribution')}. " + bins.each_with_index.map { |(_, count), index| "#{labels[index]}: #{analytics_count(count)}" }.join("; ")
      }
    }
  end

  def analytics_drill_code(code)
    code.to_s == "other" ? "outros" : code.to_s
  end

  # Funil analítico: volume, participação no total, passagem da etapa anterior (com n) e
  # quantos ficaram pelo caminho. Números vêm prontos do relatório; aqui só se formata.
  FunnelStep = Data.define(:label, :count, :share, :passage, :lost, :link)

  def analytics_funnel_steps(steps, scope:, links: {})
    first = steps.first&.last.to_i
    steps.each_with_index.map do |(key, count), index|
      previous = steps[index - 1][1].to_i if index.positive?
      FunnelStep.new(
        label: t("analytics.#{scope}.#{key}"),
        count: count,
        share: Analytics::Metric.rate(count, first),
        passage: (Analytics::Metric.rate(count, previous) if previous),
        lost: (previous - count if previous),
        link: (links[key] if analytics_drill?)
      )
    end
  end

  def analytics_bar_chart_height(count)
    [ (count * 40) + 16, 136 ].max
  end

  def analytics_result_label(code)
    t("analytics.results.#{code}", default: t("analytics.results.other"))
  end

  # Rótulo curto do eixo.
  def analytics_bucket_label(date, grouping)
    case grouping
    when Analytics::Filters::GROUPING_WEEK then l(date, format: "%d/%m")
    when Analytics::Filters::GROUPING_MONTH then l(date, format: "%b/%y")
    else l(date, format: "%d/%m")
    end
  end

  # Rótulo completo do período, para tooltip e tabela: "14 de setembro de 2026".
  def analytics_bucket_long_label(date, grouping)
    first, last = @filters.window.bucket_range(date, grouping)
    case grouping
    when Analytics::Filters::GROUPING_MONTH then l(date, format: "%B de %Y")
    when Analytics::Filters::GROUPING_WEEK
      if first.month == last.month
        "#{first.day} a #{l(last, format: '%-d de %B de %Y')}"
      else
        "#{l(first, format: '%-d de %B')} a #{l(last, format: '%-d de %B de %Y')}"
      end
    else l(date, format: "%-d de %B de %Y")
    end
  end

  def analytics_batch_code(id)
    SupplierImport.display_code_for(id)
  end
end
