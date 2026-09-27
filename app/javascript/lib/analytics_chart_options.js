import { prefersReducedMotion } from "lib/analytics_chart_theme"

// Opções do ECharts por tipo de gráfico. Os dados chegam prontos do servidor (rótulos, séries
// com o tom semântico, textos já formatados); aqui só se decide a aparência LeadPulse.
const integer = new Intl.NumberFormat("pt-BR")
const percent = new Intl.NumberFormat("pt-BR", { style: "percent", minimumFractionDigits: 1, maximumFractionDigits: 1 })
const wholePercent = new Intl.NumberFormat("pt-BR", { style: "percent", maximumFractionDigits: 0 })

const escapeHtml = (value) =>
  String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char])

function swatch(color, shape = "square") {
  const radius = shape === "line" ? "1px" : "2px"
  const size = shape === "line" ? "width:10px;height:2px" : "width:8px;height:8px"
  return `<span style="display:inline-block;${size};border-radius:${radius};background:${color};margin-right:8px;vertical-align:middle"></span>`
}

function tooltipRow(color, name, value, shape) {
  return `<div style="display:flex;align-items:center;justify-content:space-between;gap:16px;line-height:20px">` +
    `<span>${swatch(color, shape)}${escapeHtml(name)}</span>` +
    `<strong style="font-weight:600;font-variant-numeric:tabular-nums">${escapeHtml(value)}</strong></div>`
}

function tooltipTitle(text, theme) {
  return `<div style="margin-bottom:4px;color:${theme.muted};font-size:11px">${escapeHtml(text)}</div>`
}

function base(theme) {
  const animate = !prefersReducedMotion()

  return {
    animation: animate,
    animationDuration: 200,
    animationDurationUpdate: 200,
    aria: { enabled: false },
    textStyle: { fontFamily: theme.fontFamily, fontSize: 12, color: theme.muted },
    tooltip: {
      backgroundColor: theme.surface,
      borderColor: theme.line,
      borderWidth: 1,
      padding: [8, 12],
      confine: true,
      transitionDuration: animate ? 0.1 : 0,
      textStyle: { color: theme.text, fontFamily: theme.fontFamily, fontSize: 12 },
      extraCssText: `box-shadow:${theme.shadow};border-radius:8px;min-width:180px;`
    }
  }
}

function categoryAxis(theme, labels) {
  return {
    type: "category",
    data: labels,
    axisLine: { lineStyle: { color: theme.line } },
    axisTick: { show: false },
    axisLabel: { color: theme.muted, hideOverlap: true, margin: 10 }
  }
}

function valueAxis(theme, formatter = (value) => integer.format(value)) {
  return {
    type: "value",
    minInterval: 1,
    splitNumber: 4,
    axisLabel: { color: theme.muted, formatter },
    splitLine: { lineStyle: { color: theme.lineSubtle } }
  }
}

function legend(theme) {
  return {
    top: 0,
    left: 0,
    itemWidth: 10,
    itemHeight: 10,
    itemGap: 16,
    textStyle: { color: theme.textSecondary, fontSize: 12 },
    inactiveColor: theme.line
  }
}

// Colunas empilhadas por período, com o total da janela de comparação como linha discreta.
function stackedTimeline(data, theme) {
  const visible = data.series.filter((series) => series.values.some((value) => value > 0))
  const series = visible.map((item) => ({
    name: item.name,
    type: "bar",
    stack: "total",
    data: item.values,
    legendIcon: "rect",
    barMaxWidth: 28,
    itemStyle: { color: theme.tone(item.tone), borderColor: theme.surface, borderWidth: 0.5 },
    emphasis: { focus: "series" }
  }))

  if (data.previous) {
    series.push({
      name: data.previous.name,
      type: "line",
      data: data.previous.values,
      symbol: "none",
      legendIcon: "path://M0,4.5H3V5.5H0ZM3.5,4.5H6.5V5.5H3.5ZM7,4.5H10V5.5H7Z",
      z: 3,
      lineStyle: { color: theme.tone("previous"), width: 1.5, type: [4, 3] },
      itemStyle: { color: theme.tone("previous") },
      emphasis: { disabled: true }
    })
  }

  return {
    ...base(theme),
    legend: legend(theme),
    grid: { top: 40, left: 4, right: 8, bottom: 4, containLabel: true },
    xAxis: categoryAxis(theme, data.labels),
    yAxis: valueAxis(theme),
    tooltip: {
      ...base(theme).tooltip,
      trigger: "axis",
      axisPointer: { type: "shadow", shadowStyle: { color: theme.hover } },
      formatter: (params) => {
        const index = params[0]?.dataIndex ?? 0
        const rows = visible.map((item) => tooltipRow(theme.tone(item.tone), item.name, integer.format(item.values[index])))
        const total = visible.reduce((sum, item) => sum + item.values[index], 0)
        rows.push(tooltipRow("transparent", data.totalLabel, integer.format(total)))
        if (data.previous) {
          const previous = data.previous.values[index]
          rows.push(tooltipRow(theme.tone("previous"), data.previous.name, previous == null ? "—" : integer.format(previous), "line"))
        }
        return tooltipTitle(data.labels[index], theme) + rows.join("")
      }
    },
    series
  }
}

// Barras horizontais em ordem de volume, com quantidade e participação no rótulo.
function rankedBars(data, theme) {
  return {
    ...base(theme),
    grid: { top: 4, left: 4, right: 96, bottom: 4, containLabel: true },
    xAxis: { type: "value", show: false, max: (value) => value.max || 1 },
    yAxis: {
      type: "category",
      inverse: true,
      data: data.labels,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { color: theme.textSecondary, margin: 12 }
    },
    tooltip: {
      ...base(theme).tooltip,
      trigger: "item",
      formatter: (params) =>
        tooltipTitle(data.labels[params.dataIndex], theme) +
        tooltipRow(params.color, data.valueLabel, integer.format(params.value)) +
        tooltipRow("transparent", data.shareLabel, data.shares[params.dataIndex])
    },
    series: [{
      type: "bar",
      barMaxWidth: 16,
      data: data.values.map((value, index) => ({ value, itemStyle: { color: theme.tone(data.tones[index]), borderRadius: [0, 3, 3, 0] } })),
      showBackground: true,
      backgroundStyle: { color: theme.hover, borderRadius: [0, 3, 3, 0] },
      label: {
        show: true,
        position: "right",
        color: theme.textSecondary,
        fontSize: 12,
        formatter: (params) => `${integer.format(params.value)}  ${data.shares[params.dataIndex]}`
      }
    }]
  }
}

// Funil em barras horizontais na ordem das etapas, com a passagem da etapa anterior.
function funnelBars(data, theme) {
  const options = rankedBars({ ...data, tones: data.values.map(() => "brand"), shares: data.passages }, theme)
  options.series[0].label.formatter = (params) => {
    const passage = data.passages[params.dataIndex]
    return passage === "—" ? integer.format(params.value) : `${integer.format(params.value)}  ${passage}`
  }
  options.tooltip.formatter = (params) =>
    tooltipTitle(data.labels[params.dataIndex], theme) +
    tooltipRow(params.color, data.valueLabel, integer.format(params.value)) +
    tooltipRow("transparent", data.passageLabel, data.passages[params.dataIndex])
  return options
}

// Taxa por hora do dia; horas com amostra abaixo do mínimo ficam em cinza e o tooltip diz o n.
function hourlyRate(data, theme) {
  return {
    ...base(theme),
    grid: { top: 12, left: 4, right: 8, bottom: 4, containLabel: true },
    xAxis: categoryAxis(theme, data.labels),
    yAxis: { ...valueAxis(theme, (value) => wholePercent.format(value)), min: 0, max: 1, interval: 0.25 },
    tooltip: {
      ...base(theme).tooltip,
      trigger: "axis",
      axisPointer: { type: "shadow", shadowStyle: { color: theme.hover } },
      formatter: (params) => {
        const index = params[0]?.dataIndex ?? 0
        const rate = data.rates[index]
        const rows = [
          tooltipRow(data.low[index] ? theme.tone("muted") : theme.tone("brand"), data.rateLabel, rate == null ? "—" : percent.format(rate)),
          tooltipRow("transparent", data.attemptsLabel, integer.format(data.attempts[index]))
        ]
        if (data.low[index] && data.attempts[index] > 0) rows.push(`<div style="margin-top:4px;color:${theme.muted}">${escapeHtml(data.lowSampleLabel)}</div>`)
        return tooltipTitle(data.labels[index], theme) + rows.join("")
      }
    },
    series: [{
      type: "bar",
      barMaxWidth: 22,
      data: data.rates.map((rate, index) => ({
        value: rate ?? 0,
        itemStyle: { color: data.low[index] ? theme.tone("muted") : theme.tone("brand"), borderRadius: [3, 3, 0, 0] }
      }))
    }]
  }
}

const BUILDERS = {
  stacked_timeline: stackedTimeline,
  ranked_bars: rankedBars,
  funnel_bars: funnelBars,
  hourly_rate: hourlyRate
}

export function buildChartOptions(kind, data, theme) {
  const builder = BUILDERS[kind]
  if (!builder) throw new Error(`Tipo de gráfico desconhecido: ${kind}`)

  return builder(data, theme)
}
