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

  # Tom de cada resultado nos gráficos (tokens --lp-chart-*).
  RESULT_CHART_TONES = {
    "confirmed" => "confirmed",
    "rejected" => "rejected",
    "inconclusive" => "inconclusive",
    "not_answered" => "not_answered",
    "pending_dispatch" => "other",
    "other" => "other"
  }.freeze

  def analytics_tabs
    [
      [ :overview, analytics_path(@filters.to_params) ]
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

  # Célula da faixa de KPIs: valor, n com "Baixa amostra" e a comparação. Nenhuma métrica é
  # escondida por amostra pequena; só a variação deixa de ser apresentada como conclusiva.
  def analytics_kpi(key, comparison, page:)
    comparison = Analytics::Comparison.new(current: comparison, previous: nil) if comparison.is_a?(Analytics::Metric)
    metric = comparison.current
    hint = t("analytics.kpis.#{page}.#{key}.hint")

    content_tag(:div, class: "workspace-metric-card analytics-kpi", data: { metric: key }) do
      safe_join([
        content_tag(:p, class: "workspace-metric-card__label") do
          safe_join([
            content_tag(:span, t("analytics.kpis.#{page}.#{key}.label")),
            content_tag(:i, "", class: "fa-solid fa-circle-info analytics-kpi__hint", title: hint, role: "img", aria: { label: hint })
          ])
        end,
        content_tag(:p, analytics_metric_value(metric), class: "workspace-metric-card__value"),
        analytics_sample(metric),
        analytics_comparison(key, comparison)
      ].compact)
    end
  end

  def analytics_sample(metric)
    return if metric.kind == :count

    content_tag(:p, class: "analytics-kpi__sample") do
      safe_join([
        content_tag(:span, t("analytics.metric.sample", count: analytics_count(metric.sample))),
        (analytics_low_sample_flag if metric.low_sample?)
      ].compact)
    end
  end

  def analytics_low_sample_flag
    content_tag(:span, t("analytics.metric.low_sample"), class: "analytics-low-sample", title: t("analytics.metric.low_sample_hint"))
  end

  def analytics_comparison(key, comparison)
    case comparison.status
    when :ok then analytics_delta(key, comparison)
    when :low_sample
      content_tag(:p, class: "analytics-delta analytics-delta--muted", title: t("analytics.metric.low_sample_hint")) do
        previous = analytics_metric_value(comparison.previous)
        previous += " (#{t('analytics.metric.sample', count: analytics_count(comparison.previous.sample))})" unless comparison.previous.kind == :count
        t("analytics.metric.previous", value: previous)
      end
    when :no_base
      content_tag(:p, t("analytics.metric.no_base"), class: "analytics-delta analytics-delta--muted")
    end
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
    labels = data[:rows].map { |row| analytics_bucket_label(row[:date], data[:grouping]) }
    series = EVOLUTION_RESULTS.map do |code|
      { name: analytics_result_label(code), tone: code, values: data[:rows].map { |row| row[code.to_sym] } }
    end
    previous = data[:previous_totals] && { name: t("analytics.sections.evolution_previous"), values: data[:previous_totals] }

    head = [ t("analytics.chart.period") ] + series.map { |item| item[:name] } + [ t("analytics.chart.total") ]
    head << previous[:name] if previous
    rows = data[:rows].each_with_index.map do |row, index|
      cells = [ labels[index] ] + EVOLUTION_RESULTS.map { |code| analytics_count(row[code.to_sym]) } + [ analytics_count(row[:records]) ]
      cells << analytics_count(previous[:values][index]) if previous
      cells
    end

    total = data[:rows].sum { |row| row[:records] }
    parts = series.filter_map { |item| "#{item[:name]}: #{analytics_count(item[:values].sum)}" if item[:values].sum.positive? }
    {
      head: head,
      rows: rows,
      chart: {
        kind: "stacked_timeline",
        height: 280,
        data: { labels: labels, series: series, previous: previous, totalLabel: t("analytics.chart.total") },
        summary: t("analytics.chart.summary.evolution", total: analytics_count(total), window: @filters.window.label, parts: parts.join("; "))
      }
    }
  end

  def analytics_distribution_chart(title, counts, label: method(:analytics_result_label), tone: ->(code) { RESULT_CHART_TONES.fetch(code, "other") })
    total = counts.values.sum
    items = counts.reject { |_, count| count.zero? }.sort_by { |_, count| -count }
    labels = items.map { |code, _| label.call(code) }
    shares = items.map { |_, count| analytics_percent(total.positive? ? count.to_f / total : nil) }

    {
      head: [ title, t("analytics.table.records"), t("analytics.chart.share") ],
      rows: items.each_with_index.map { |(_, count), index| [ labels[index], analytics_count(count), shares[index] ] },
      chart: {
        kind: "ranked_bars",
        height: analytics_bar_chart_height(items.size),
        data: {
          labels: labels,
          values: items.map(&:last),
          tones: items.map { |code, _| tone.call(code) },
          shares: shares,
          valueLabel: t("analytics.table.records"),
          shareLabel: t("analytics.chart.share")
        },
        summary: "#{title}. " + items.each_with_index.map { |(_, count), index| "#{labels[index]}: #{analytics_count(count)} (#{shares[index]})" }.join("; ")
      }
    }
  end

  def analytics_funnel_chart(title, steps, scope:)
    labels = steps.map { |step, _| t("analytics.#{scope}.#{step}") }
    passages = steps.each_with_index.map do |(_, count), index|
      next "—" if index.zero?

      previous = steps[index - 1][1].to_i
      analytics_percent(previous.positive? ? count.to_f / previous : nil)
    end

    {
      head: [ title, t("analytics.table.records"), t("analytics.sections.funnel_drop") ],
      rows: steps.each_with_index.map { |(_, count), index| [ labels[index], analytics_count(count), passages[index] ] },
      chart: {
        kind: "funnel_bars",
        height: analytics_bar_chart_height(steps.size),
        data: {
          labels: labels,
          values: steps.map(&:last),
          passages: passages,
          valueLabel: t("analytics.table.records"),
          passageLabel: t("analytics.sections.funnel_drop")
        },
        summary: "#{title}. " + steps.each_with_index.map { |(_, count), index| "#{labels[index]}: #{analytics_count(count)}" }.join("; ")
      }
    }
  end

  def analytics_bar_chart_height(count)
    [ (count * 40) + 16, 136 ].max
  end

  def analytics_result_label(code)
    t("analytics.results.#{code}", default: t("analytics.results.other"))
  end

  def analytics_bucket_label(date, grouping)
    return t("analytics.chart.week_of", date: l(date, format: "%d/%m")) if grouping == Analytics::Filters::GROUPING_WEEK

    l(date, format: "%d/%m")
  end

  def analytics_batch_code(id)
    SupplierImport.display_code_for(id)
  end
end
