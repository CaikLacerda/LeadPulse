import { mix, prefersReducedMotion } from "lib/analytics_chart_theme"

// Opções do ECharts por tipo de gráfico. Os dados chegam prontos do servidor (rótulos, séries
// com o tom semântico, textos já formatados); aqui só se decide a aparência LeadPulse.
const integer = new Intl.NumberFormat("pt-BR")

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
    animationDurationUpdate: 180,
    animationEasing: "cubicOut",
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
      extraCssText: `box-shadow:${theme.shadow};border-radius:8px;min-width:190px;max-width:300px;white-space:normal;`
    }
  }
}

// No máximo ~1 rótulo a cada 72px: evita a "parede de datas"; o tooltip traz a data exata.
function categoryAxis(theme, labels, context) {
  const maxLabels = Math.max(4, Math.floor((context.width || 800) / 72))
  const interval = labels.length > maxLabels ? Math.ceil(labels.length / maxLabels) - 1 : 0

  return {
    type: "category",
    data: labels,
    axisLine: { lineStyle: { color: theme.line } },
    axisTick: { show: false },
    axisLabel: { color: theme.muted, interval, hideOverlap: true, margin: 10 }
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

// Uma linha só; em telas estreitas a legenda pagina com setas em vez de cobrir o gráfico.
function legend(theme) {
  return {
    type: "scroll",
    pageIconColor: theme.textSecondary,
    pageIconInactiveColor: theme.line,
    pageTextStyle: { color: theme.muted },
    top: 0,
    left: 0,
    right: 0,
    itemWidth: 10,
    itemHeight: 10,
    itemGap: 16,
    textStyle: { color: theme.textSecondary, fontSize: 12 },
    inactiveColor: theme.line
  }
}

function divider(theme) {
  return `<div style="margin:6px 0;border-top:1px solid ${theme.lineSubtle}"></div>`
}

function note(text, theme) {
  return `<div style="margin-top:2px;color:${theme.muted};line-height:18px">${escapeHtml(text)}</div>`
}

// Colunas empilhadas por período, com o total da janela de comparação como linha discreta.
function stackedTimeline(data, theme, context) {
  const visible = data.series.filter((series) => series.values.some((value) => value > 0))
  const clickable = Boolean(data.drill)
  const series = visible.map((item) => ({
    name: item.name,
    type: "bar",
    stack: "total",
    data: item.values,
    legendIcon: "rect",
    barMaxWidth: 28,
    cursor: clickable ? "pointer" : "default",
    itemStyle: { color: theme.tone(item.tone), borderColor: theme.surface, borderWidth: 1 },
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
    xAxis: categoryAxis(theme, data.labels, context),
    yAxis: valueAxis(theme),
    tooltip: {
      ...base(theme).tooltip,
      trigger: "axis",
      axisPointer: { type: "shadow", shadowStyle: { color: theme.hover } },
      formatter: (params) => {
        const index = params[0]?.dataIndex ?? 0
        const rows = visible.filter((item) => item.values[index] > 0)
          .map((item) => tooltipRow(theme.tone(item.tone), item.name, integer.format(item.values[index])))
        const total = visible.reduce((sum, item) => sum + item.values[index], 0)
        let html = tooltipTitle(data.longLabels?.[index] || data.labels[index], theme)
        html += tooltipRow("transparent", data.totalLabel, integer.format(total))
        if (rows.length) html += divider(theme) + rows.join("")
        const extras = data.extras?.[index] || []
        if (extras.length) html += divider(theme) + extras.map(([name, value]) => tooltipRow("transparent", name, value)).join("")
        if (data.previous) {
          const previous = data.previous.values[index]
          html += divider(theme) + tooltipRow(theme.tone("previous"), data.previous.name, previous == null ? "—" : integer.format(previous), "line")
          if (data.differences?.[index]) html += note(`${data.differenceLabel}: ${data.differences[index]}`, theme)
        }
        if (clickable && total > 0) html += note("Clique para ver os itens", theme)
        return html
      }
    },
    series
  }
}

// Barras horizontais em ordem de volume, com quantidade e participação no rótulo.
function rankedBars(data, theme) {
  const clickable = Boolean(data.links)

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
        tooltipRow("transparent", data.shareLabel, data.shares[params.dataIndex]) +
        (clickable ? note("Clique para ver os itens", theme) : "")
    },
    series: [{
      type: "bar",
      barMaxWidth: 16,
      cursor: clickable ? "pointer" : "default",
      data: data.values.map((value, index) => ({ value, itemStyle: { color: theme.tone(data.tones[index]), borderRadius: [0, 3, 3, 0] } })),
      showBackground: true,
      backgroundStyle: { color: theme.hover, borderRadius: [0, 3, 3, 0] },
      emphasis: { itemStyle: { opacity: 0.85 } },
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

// Mapa de calor dia da semana × hora. Modo "volume" (tentativas) ou "rate" (taxa de
// atendimento). Escala sequencial de um só tom a partir dos tokens; células com amostra
// baixa ganham hachura no modo taxa, e o tooltip sempre traz o n. A legenda da escala é HTML
// do design system (analytics-scale); o visualMap do ECharts só faz o mapeamento de cor.
// O texto da taxa vem pronto do servidor ("50,0% · n = 8 · Baixa amostra"): a taxa fica na
// linha e a amostra vai para a nota, sem quebrar a coluna de valores.
function heatmapTooltip(data, cell, theme, clickable) {
  const [rate, ...sample] = String(cell[6]).split(" · ")
  return tooltipTitle(`${data.dayNames[cell[1]]}, ${data.hourNames[cell[0]]}`, theme) +
    tooltipRow("transparent", data.labels.attempts, integer.format(cell[2])) +
    tooltipRow("transparent", data.labels.answered, integer.format(cell[3])) +
    tooltipRow("transparent", data.labels.rate, rate) +
    (sample.length ? note(sample.join(" · "), theme) : "") +
    (clickable ? note("Clique para ver as tentativas", theme) : "")
}

function heatmap(data, theme, context) {
  const rateMode = context.mode === "rate"
  const clickable = Boolean(data.links)
  const background = []
  data.days.forEach((_, day) => data.hours.forEach((_, hour) => background.push([hour, day, 0])))
  const points = data.cells
    .map((cell, index) => ({ cell, index }))
    .filter(({ cell }) => (rateMode ? cell[4] !== null : cell[2] > 0))
    .map(({ cell, index }) => ({
      value: [cell[0], cell[1], rateMode ? cell[4] : cell[2]],
      linkIndex: index,
      itemStyle: rateMode && cell[5] ? { decal: { symbol: "rect", color: theme.decal, dashArrayX: [1, 0], dashArrayY: [2, 4], rotation: -Math.PI / 4 } } : undefined
    }))
  const max = rateMode ? 1 : Math.max(1, ...data.cells.map((cell) => cell[2]))
  const narrow = (context.width || 800) < 640

  return {
    ...base(theme),
    grid: { top: 6, left: 4, right: 8, bottom: 4, containLabel: true },
    xAxis: {
      type: "category",
      data: data.hours,
      axisLine: { lineStyle: { color: theme.line } },
      axisTick: { show: false },
      axisLabel: { color: theme.muted, interval: narrow ? 3 : 1 }
    },
    yAxis: {
      type: "category",
      data: data.days,
      inverse: true,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { color: theme.textSecondary }
    },
    visualMap: {
      type: "continuous",
      show: false,
      seriesIndex: 1,
      min: 0,
      max,
      dimension: 2,
      inRange: { color: [theme.sequentialLow, theme.sequentialHigh] }
    },
    tooltip: {
      ...base(theme).tooltip,
      trigger: "item",
      formatter: (params) => {
        if (params.seriesIndex === 0) return ""
        return heatmapTooltip(data, data.cells[params.data.linkIndex], theme, clickable)
      }
    },
    series: [
      {
        type: "heatmap",
        data: background,
        silent: true,
        itemStyle: { color: theme.lineSubtle, borderColor: theme.surface, borderWidth: 2, borderRadius: 3 },
        tooltip: { show: false }
      },
      {
        type: "heatmap",
        data: points,
        cursor: clickable ? "pointer" : "default",
        itemStyle: { borderColor: theme.surface, borderWidth: 2, borderRadius: 3 },
        emphasis: { itemStyle: { borderColor: theme.text, borderWidth: 1 } }
      }
    ]
  }
}

// Distribuição em faixas ordenadas (histograma): um só tom, faixas lado a lado com trilho
// discreto, contagem no topo e a participação de cada faixa no tooltip. O servidor diz em que
// faixa caem a mediana e o p90 (etiquetas acima da barra) e, quando existe, onde começa a
// cauda longa (faixa hachurada, com fundo e rótulo próprios). Nada é recalculado aqui.
function histogram(data, theme, context) {
  const clickable = Boolean(data.links)
  const markers = data.markers || []
  const tailFrom = data.tail ? data.tail.from : null
  const inTail = (index) => tailFrom !== null && index >= tailFrom
  // Com espaço, a etiqueta traz o valor ("Mediana 2 min 07 s"); estreito, só o nome.
  const narrow = (context.width || 800) < 560
  const tags = (index) => markers.filter((marker) => marker.index === index)
    .map((marker) => (narrow ? marker.label : `${marker.label} ${marker.value}`)).join(" · ")
  const tailColor = mix(theme.surface, theme.tone("brand"), 0.55)
  const hatch = { symbol: "rect", color: theme.decal, dashArrayX: [1, 0], dashArrayY: [2, 5], rotation: -Math.PI / 4 }
  const lastIndex = data.labels.length - 1

  return {
    ...base(theme),
    grid: { top: 48, left: 4, right: 8, bottom: 4, containLabel: true },
    xAxis: {
      ...categoryAxis(theme, data.labels, context),
      axisLabel: {
        color: theme.muted,
        interval: 0,
        hideOverlap: false,
        margin: 10,
        // Estreito: número e unidade em duas linhas ("10–60" / "min"), sem esconder faixa.
        formatter: (label, index) => {
          const text = narrow ? label.replace(/ (?=[^ ]*$)/, "\n") : label
          return inTail(index) ? `{tail|${text}}` : text
        },
        lineHeight: 14,
        rich: { tail: { color: theme.textSecondary, fontWeight: 600, lineHeight: 14 } }
      }
    },
    // Contagens já estão no topo de cada barra: o eixo Y só daria ruído.
    yAxis: { type: "value", show: false, max: (value) => Math.max(1, value.max) },
    tooltip: {
      ...base(theme).tooltip,
      trigger: "item",
      formatter: (params) => {
        const index = params.dataIndex
        let html = tooltipTitle(data.longLabels[index], theme) +
          tooltipRow(theme.tone("brand"), data.valueLabel, integer.format(params.value)) +
          tooltipRow("transparent", data.shareLabel, data.shares[index])
        const notes = markers.filter((marker) => marker.index === index).map((marker) => marker.note)
        if (inTail(index)) notes.push(data.tail.note)
        if (notes.length) html += divider(theme) + notes.map((text) => note(text, theme)).join("")
        if (clickable && params.value > 0) html += note("Clique para ver as tentativas", theme)
        return html
      }
    },
    series: [{
      type: "bar",
      cursor: clickable ? "pointer" : "default",
      data: data.values.map((value, index) => ({
        value,
        itemStyle: inTail(index) ? { color: tailColor, decal: hatch } : undefined
      })),
      barCategoryGap: "18%",
      showBackground: true,
      backgroundStyle: { color: theme.hover, borderRadius: [4, 4, 0, 0] },
      itemStyle: { color: theme.tone("brand"), borderRadius: [4, 4, 0, 0] },
      emphasis: { focus: "self" },
      blur: { itemStyle: { opacity: 0.35 } },
      label: {
        show: true,
        position: "top",
        distance: 6,
        formatter: (params) => {
          const count = params.value > 0 ? `{count|${integer.format(params.value)}}` : ""
          const tag = tags(params.dataIndex)
          return tag ? `{tag|${tag}}\n${count}` : count
        },
        rich: {
          count: { color: theme.textSecondary, fontSize: 11, fontWeight: 600, lineHeight: 16 },
          tag: {
            color: theme.text,
            backgroundColor: theme.surface,
            borderColor: theme.line,
            borderWidth: 1,
            borderRadius: 4,
            padding: [2, 6],
            fontSize: 10,
            fontWeight: 600,
            lineHeight: 14
          }
        }
      },
      markArea: tailFrom === null ? undefined : {
        silent: true,
        itemStyle: { color: theme.hover, opacity: 0.6 },
        label: { show: !narrow, position: "insideTop", distance: 4, color: theme.muted, fontSize: 10, formatter: data.tail.label },
        data: [[{ xAxis: data.labels[tailFrom] }, { xAxis: data.labels[lastIndex] }]]
      }
    }]
  }
}

// Mesmas células do mapa de calor em barras 3D (ECharts GL): altura = tentativas ou taxa. É uma
// visão exploratória para desktop; o mapa 2D e a tabela continuam sendo a leitura de referência.
// Câmera com limites (sem giro automático, sem zoom pela roda para não prender a rolagem da página).
// center abaixo do meio da caixa: a borda da frente (mais perto da câmera) não sai do quadro.
const CAMERA = { alpha: 22, beta: 18, distance: 190, center: [0, -24, 0] }

function heatmap3d(data, theme, context) {
  const rateMode = context.mode === "rate"
  const clickable = Boolean(data.links)
  const animate = !prefersReducedMotion()
  const max = rateMode ? 1 : Math.max(1, ...data.cells.map((cell) => cell[2]))
  const axisStyle = {
    axisLine: { lineStyle: { color: theme.line } },
    axisTick: { show: false },
    splitLine: { show: true, lineStyle: { color: theme.lineSubtle } },
    axisLabel: { textStyle: { color: theme.muted, fontSize: 11 } },
    nameTextStyle: { color: theme.textSecondary, fontSize: 11 },
    axisPointer: { lineStyle: { color: theme.muted } }
  }
  const points = data.cells
    .map((cell, index) => ({ cell, index }))
    .filter(({ cell }) => (rateMode ? cell[4] !== null : cell[2] > 0))
    .map(({ cell, index }) => {
      const value = rateMode ? cell[4] : cell[2]
      // Na taxa, célula com pouca amostra fica neutra: altura sem cor não vira conclusão.
      const color = rateMode && cell[5] ? mix(theme.surface, theme.muted, 0.6) : mix(theme.sequentialLow, theme.sequentialHigh, 0.25 + 0.75 * (value / max))
      return { value: [cell[0], cell[1], value], linkIndex: index, itemStyle: { color } }
    })

  return {
    ...base(theme),
    tooltip: {
      ...base(theme).tooltip,
      trigger: "item",
      formatter: (params) => {
        return heatmapTooltip(data, data.cells[params.data.linkIndex], theme, clickable)
      }
    },
    xAxis3D: { type: "category", data: data.hours, name: data.labels.hour || "", nameGap: 18, ...axisStyle, axisLabel: { ...axisStyle.axisLabel, interval: 2, formatter: (value) => (value === data.hours[0] ? "" : value) } },
    yAxis3D: { type: "category", data: data.days, name: "", ...axisStyle },
    // O nome da medida fica na legenda (analytics-scale), sem disputar espaço com os números.
    zAxis3D: {
      type: "value",
      name: "",
      min: 0,
      max: rateMode ? 1 : undefined,
      minInterval: rateMode ? undefined : 1,
      ...axisStyle,
      axisLabel: { ...axisStyle.axisLabel, formatter: (value) => (rateMode ? `${Math.round(value * 100)}%` : integer.format(value)) }
    },
    grid3D: {
      boxWidth: 200,
      boxDepth: 92,
      boxHeight: 76,
      top: 0,
      bottom: 0,
      environment: "none",
      axisLine: { lineStyle: { color: theme.line } },
      splitLine: { lineStyle: { color: theme.lineSubtle } },
      axisPointer: { lineStyle: { color: theme.muted } },
      light: { main: { intensity: 1.05, alpha: 45, beta: 30 }, ambient: { intensity: 0.5 } },
      viewControl: {
        projection: "perspective",
        autoRotate: false,
        ...CAMERA,
        minAlpha: 10,
        maxAlpha: 45,
        minBeta: -20,
        maxBeta: 30,
        minDistance: CAMERA.distance,
        maxDistance: CAMERA.distance,
        rotateSensitivity: 1,
        zoomSensitivity: 0,
        panSensitivity: 0,
        damping: 0.85,
        animation: animate,
        animationDurationUpdate: animate ? 250 : 0
      }
    },
    series: [{
      type: "bar3D",
      data: points,
      shading: "lambert",
      bevelSize: 0.3,
      bevelSmoothness: 2,
      barSize: [5.8, 8],
      silent: false,
      itemStyle: { opacity: 1 },
      emphasis: { label: { show: false }, itemStyle: { color: theme.tone("brand") } },
      animation: animate,
      animationDurationUpdate: animate ? 200 : 0
    }]
  }
}

const BUILDERS = {
  stacked_timeline: stackedTimeline,
  ranked_bars: rankedBars,
  heatmap,
  heatmap3d,
  histogram
}

export function buildChartOptions(kind, data, theme, context = {}) {
  const builder = BUILDERS[kind]
  if (!builder) throw new Error(`Tipo de gráfico desconhecido: ${kind}`)

  return builder(data, theme, context)
}

// Destino do drill-down para um clique no gráfico, a partir dos links que o servidor mandou.
// Sem permissão para ver registros, o servidor não manda links e o clique não faz nada.
export function drillTarget(kind, data, params) {
  if (kind === "ranked_bars") return data.links?.[params.dataIndex] || null
  if (kind === "histogram") return data.links?.[params.dataIndex] || null
  if (kind === "heatmap3d") return data.links?.[params.data?.linkIndex] || null
  if (kind === "heatmap") return params.seriesIndex === 1 ? data.links?.[params.data.linkIndex] || null : null
  if (kind === "stacked_timeline" && data.drill && params.seriesType === "bar") {
    const series = data.series.filter((item) => item.values.some((value) => value > 0))[params.seriesIndex]
    const range = data.drill.ranges[params.dataIndex]
    if (!series || !range) return null
    const url = new URL(data.drill.base, window.location.origin)
    url.searchParams.set("periodo", "personalizado")
    url.searchParams.set("de", range[0])
    url.searchParams.set("ate", range[1])
    url.searchParams.set(data.drill.param, series.code === "other" ? "outros" : series.code)
    return url.pathname + url.search
  }
  return null
}
