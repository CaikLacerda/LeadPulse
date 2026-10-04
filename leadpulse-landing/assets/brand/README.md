# Marca

## Situação atual

**Não existe arquivo de logo do LeadPulse.** Nenhum SVG, PNG ou arquivo de design de marca foi encontrado nos repositórios.

O que existe no app Rails:

| Elemento | Onde | Como é |
| --- | --- | --- |
| Símbolo | `app/views/shared/_site_header.html.erb`, `_app_sidebar.html.erb`, `layouts/devise.html.erb` | Quadrado de 28 px com cantos de 7 px e ícone Font Awesome `fa-solid fa-bolt` (raio) |
| Cores do símbolo | `app/assets/tailwind/base/tokens.css` (`--lp-logo-bg`, `--lp-logo-fg`) | Tema claro: fundo `#111827`, raio `#fb8a2e`. Tema escuro: fundo `#f4f5f7`, raio `#f97316` |
| Wordmark | Mesmos arquivos (`.app-logo-text`) | Texto "LeadPulse" em Inter, peso semibold |
| Favicon | `public/icon.png`, `public/icon.svg` | **Placeholder padrão do Rails (círculo vermelho). Não usar.** |

O ícone de raio é um ícone genérico de biblioteca, não um símbolo próprio. Para uma landing premium, o ideal é ter um logo desenhado. A decisão é do usuário.

## Tokens visuais existentes

Ponto de partida, não paleta final da landing.

**Workspace** (`app/assets/tailwind/base/tokens.css`):

| Token | Claro | Escuro |
| --- | --- | --- |
| `--color-brand` | `#2563eb` | `#2563eb` |
| `--color-brand-fg` | `#1d4ed8` | `#86b0ff` |
| `--color-surface` | `#ffffff` | `#15171b` |
| `--lp-accent` / `--lp-accent-fg` | `#fb8a2e` / `#c2410c` | — |

**Sala de voz da simulação**, tema escuro próprio (`app/assets/tailwind/pages/simulation_voice.css`, trabalho em andamento na branch `feat/simulacoes`). É a referência interna mais próxima da direção dark, navy e ciano pedida para a landing:

| Token | Valor | Papel |
| --- | --- | --- |
| `--color-canvas` | `#080f1b` | fundo |
| `--color-surface` | `#0e1827` | superfícies |
| `--color-surface-subtle` | `#111e30` | superfícies secundárias |
| `--color-line` | `#263549` | bordas |
| `--color-fg` | `#e9eff8` | texto principal |
| `--color-fg-muted` | `#9aaac0` | texto secundário |
| `--color-brand` | `#55c4ed` | ciano de destaque |
| `--sim-agent-accent` | `#6dd5f4` | agente |
| `--sim-counterpart-accent` | `#8eaee8` | contraparte |
| fundo do palco | `radial-gradient(ellipse at 45% 0%, #122037 0%, #080f1b 65%)` | profundidade |

**Tipografia** (`tokens.css`): `--font-sans: "Inter"` e `--font-mono: "JetBrains Mono"`.

Hoje há três acentos convivendo: azul `#2563eb` no workspace, laranja `#fb8a2e` no símbolo e no selo da landing atual, e ciano `#55c4ed` na sala de voz. A landing precisa de uma decisão de acento. O Astra deve propor e o usuário aprova.

## O que deve ser colocado aqui

| Arquivo sugerido | Conteúdo | Status |
| --- | --- | --- |
| `logo-horizontal.svg` | Símbolo + wordmark, para fundo escuro | falta |
| `logo-horizontal-light.svg` | Versão para fundo claro | falta |
| `logo-symbol.svg` | Só o símbolo (favicon, avatar, app) | falta |
| `logo-mono.svg` | Versão monocromática | falta |
| `favicon.svg`, `favicon-32.png`, `apple-touch-icon.png` | Ícones de navegador | falta |
| `og-image.png` (1200 × 630) | Imagem de compartilhamento da nova landing | falta |
| `brand-colors.md` | Paleta final aprovada da landing | falta |

Formato preferido: SVG vetorial. PNGs são derivados.

## Marcas de terceiros

Não colocar aqui logos de OpenAI, Twilio, Meta/WhatsApp, Qwen/Alibaba, Ollama, AWS ou outras empresas. Um logo de terceiro só deve ser considerado se as três condições forem atendidas:

1. a integração existe de fato (ver `docs/TECHNOLOGY_ECOSYSTEM.md`);
2. as diretrizes de marca do dono permitem esse uso;
3. o uso não sugere parceria oficial, que não existe.

## Nome

- Nome público: **LeadPulse**.
- `api_confaith_ai`, "Confaith" e `confaith-*` são nomes internos de serviço e infraestrutura. Não devem aparecer na landing.
