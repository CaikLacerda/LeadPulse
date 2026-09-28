// Tema dos gráficos a partir dos tokens do design system. É lido na hora de desenhar, então
// claro e escuro saem das mesmas variáveis CSS e trocar o tema só exige redesenhar.
const TONE_TOKENS = {
  confirmed: "--lp-chart-confirmed",
  rejected: "--lp-chart-rejected",
  inconclusive: "--lp-chart-inconclusive",
  not_answered: "--lp-chart-not-answered",
  other: "--lp-chart-other",
  brand: "--lp-chart-bar",
  previous: "--lp-chart-previous",
  muted: "--lp-chart-muted"
}

// Mistura duas cores hex em proporção; usado só para derivar a escala sequencial dos tokens.
// Aceita #rgb também: o CSS minificado encurta #ffffff para #fff.
export function mix(from, to, amount) {
  const parse = (hex) => {
    let digits = hex.trim().replace("#", "")
    if (digits.length === 3) digits = [...digits].map((digit) => digit + digit).join("")
    if (digits.length !== 6) return [NaN]
    return [0, 2, 4].map((start) => parseInt(digits.slice(start, start + 2), 16))
  }
  const [a, b] = [parse(from), parse(to)]
  if (a.some(Number.isNaN) || b.some(Number.isNaN)) return to
  return "#" + a.map((value, index) => Math.round(value + (b[index] - value) * amount).toString(16).padStart(2, "0")).join("")
}

export function chartTheme(element = document.documentElement) {
  const styles = getComputedStyle(element)
  const token = (name) => styles.getPropertyValue(name).trim()
  const tones = Object.fromEntries(Object.entries(TONE_TOKENS).map(([tone, name]) => [tone, token(name)]))
  const surface = token("--color-surface")
  const brand = token("--color-brand")

  return {
    fontFamily: getComputedStyle(document.body).fontFamily,
    text: token("--color-fg"),
    textSecondary: token("--color-fg-secondary"),
    muted: token("--color-fg-muted"),
    line: token("--color-line"),
    lineSubtle: token("--color-line-subtle"),
    surface,
    // Escala sequencial (um só tom): do quase-fundo ao azul de texto da marca. No claro vai do
    // claro ao escuro; no escuro, do escuro ao claro, porque os tokens já trocam de lado.
    sequentialLow: mix(surface, brand, 0.16),
    sequentialHigh: token("--color-brand-fg"),
    decal: token("--color-fg-muted"),
    hover: token("--lp-chart-column-hover"),
    shadow: token("--lp-shadow-lg"),
    tones,
    tone: (name) => tones[name] || tones.other
  }
}

export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}
