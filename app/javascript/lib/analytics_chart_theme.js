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

export function chartTheme(element = document.documentElement) {
  const styles = getComputedStyle(element)
  const token = (name) => styles.getPropertyValue(name).trim()
  const tones = Object.fromEntries(Object.entries(TONE_TOKENS).map(([tone, name]) => [tone, token(name)]))

  return {
    fontFamily: getComputedStyle(document.body).fontFamily,
    text: token("--color-fg"),
    textSecondary: token("--color-fg-secondary"),
    muted: token("--color-fg-muted"),
    line: token("--color-line"),
    lineSubtle: token("--color-line-subtle"),
    surface: token("--color-surface"),
    hover: token("--lp-chart-column-hover"),
    shadow: token("--lp-shadow-lg"),
    tones,
    tone: (name) => tones[name] || tones.other
  }
}

export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}
