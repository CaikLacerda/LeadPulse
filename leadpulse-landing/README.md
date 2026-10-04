# LeadPulse — pacote de contexto da landing page

Este diretório reúne materiais, assets e documentação para planejar e construir a futura landing page do LeadPulse.

**Ele não contém código da landing page.** Não há HTML, CSS, JavaScript nem componentes aqui. O conteúdo é o insumo para a próxima etapa: o GPT-6 Astra analisa o material, propõe o plano e só implementa depois que o plano for aprovado.

Preparado em 15/10/2026 a partir dos repositórios `LeadPulse` (Rails, branch `feat/simulacoes`) e `api_confaith_ai` (FastAPI, branch `feat/simulacoes`). Toda funcionalidade marcada como **CURRENT** nos documentos foi conferida no código.

## Visão geral

O LeadPulse nasceu como TCC, com um caso concreto: qualificar e validar telefones de fornecedores com IA conversacional por voz. Esse caso funciona e continua sendo o primeiro workflow da plataforma, a prova de conceito e o cenário de testes.

A visão comercial é mais ampla: uma plataforma B2B para criar, configurar, executar, acompanhar e avaliar fluxos de IA conversacional por voz. A empresa define o processo e a IA conduz a conversa. A landing page deve comunicar essa visão **sem apresentar recursos futuros como prontos**.

Comece por [docs/ASTRA_HANDOFF.md](docs/ASTRA_HANDOFF.md).

## Estrutura

```text
leadpulse-landing/
├── README.md                     este arquivo
├── references/                   referência visual (inspiração, não cópia)
│   ├── README.md
│   ├── landing-reference.jpg     landing de referência ("Agex")
│   └── current-leadpulse-site/   landing pública atual do Rails (contexto, não referência)
├── assets/
│   ├── hero/                     vídeo do hero em loop
│   │   ├── README.md
│   │   ├── hero-video-loop.mp4
│   │   └── frames/               4 quadros extraídos só para análise
│   └── brand/                    marca (ainda sem arquivo de logo)
│       └── README.md
├── screenshots/                  telas reais do produto
│   ├── README.md
│   └── 01…07                     simulação, analytics, conversa, lote, busca
└── docs/
    ├── BRIEF.md                  resumo executivo
    ├── PRODUCT_VISION.md         origem, produto atual, visão, CURRENT vs FUTURE
    ├── AUDIENCE.md               público, decisores, dores, linguagem
    ├── CONTENT_DIRECTION.md      tom, mensagens, seções, headlines, CTAs, visual
    ├── TECHNOLOGY_ECOSYSTEM.md   stack, provedores, integrações, tabela de status
    └── ASTRA_HANDOFF.md          entrada única para o próximo agente
```

| Pasta | Finalidade |
| --- | --- |
| `references/` | Referência de composição, hierarquia, ritmo e acabamento. Não deve ser copiada. |
| `assets/hero/` | Vídeo de fundo do hero e quadros de análise. |
| `assets/brand/` | Logo, ícones, cores e tipografia. Hoje documenta a marca existente e lista o que falta. |
| `screenshots/` | Telas reais do LeadPulse. Têm prioridade sobre qualquer interface ilustrativa. |
| `docs/` | Contexto de produto, público, conteúdo, tecnologia e handoff. |

## Arquivos encontrados e copiados

Todos os originais foram preservados. Nada foi movido nem apagado.

| Original | Cópia | Observação |
| --- | --- | --- |
| `LeadPulse/4f51b741739f48f16b22532074a79d18.jpg` | `references/landing-reference.jpg` | Referência visual indicada pelo usuário. Cópia idêntica (`cmp`). |
| `LeadPulse/hero-video-loop.mp4` | `assets/hero/hero-video-loop.mp4` | Vídeo do hero indicado pelo usuário. Cópia idêntica (`cmp`). |
| `LeadPulse/tmp/orbital-ui/desktop.png` | `screenshots/01-simulation-live-desktop-1280.png` | Render offline da view real de simulação (ver ressalvas em `screenshots/README.md`). |
| `LeadPulse/tmp/orbital-ui/desktop-full.png` | `screenshots/02-simulation-live-full-page.png` | Mesma tela, página inteira, com a conversa. |
| `LeadPulse/tmp/orbital-ui/mobile.png` | `screenshots/03-simulation-live-mobile-390.png` | Mesma tela em 390 px. |
| `LeadPulse/app/assets/images/landing/produto-analytics-1600.webp` | `screenshots/04-analytics-overview-1600.webp` | Usada hoje na landing pública do Rails. |
| `LeadPulse/app/assets/images/landing/produto-chamada-1200.webp` | `screenshots/05-call-transcript-human-review-1200.webp` | Idem. |
| `LeadPulse/app/assets/images/landing/produto-lote-1200.webp` | `screenshots/06-batch-records-1200.webp` | Idem. |
| `LeadPulse/app/assets/images/landing/produto-busca-1200.webp` | `screenshots/07-supplier-search-1200.webp` | Idem. |
| `LeadPulse/docs/redesign-publico/screenshots/depois/landing-1440.jpg` | `references/current-leadpulse-site/landing-1440-full.jpg` | Landing pública atual (posicionamento antigo). |
| `LeadPulse/docs/redesign-publico/screenshots/depois/landing-1440-viewport.jpg` | `references/current-leadpulse-site/landing-1440-hero.jpg` | Hero da landing atual. |

Arquivo derivado criado: `assets/hero/frames/frame-*.jpg`, 4 quadros extraídos da cópia do vídeo com `ffmpeg`, só para análise. O vídeo não foi editado.

Encontrados e **não** copiados, com o motivo:

| Arquivo | Motivo |
| --- | --- |
| `LeadPulse/public/icon.png`, `public/icon.svg` | Placeholder padrão do Rails (círculo vermelho). Não é marca do LeadPulse. |
| `app/assets/images/landing/og-leadpulse.jpg` | Recorte da mesma tela de Analytics (1200×630), já coberta pela captura 04. |
| Versões `-640`/`-800` das imagens da landing | Tamanhos menores das mesmas imagens. |
| `docs/redesign-publico/screenshots/` (login, cadastro, versões "antes") | Telas de autenticação e versões anteriores, pouco relevantes para a nova landing. |
| Documentos `.docx`/`.md` dos repositórios | Foram lidos e resumidos em `docs/`. Os originais continuam onde estão (lista em `docs/ASTRA_HANDOFF.md`). |

## Assets existentes e faltantes

| Asset | Situação |
| --- | --- |
| Referência visual | Existe (`references/landing-reference.jpg`). |
| Vídeo do hero | Existe (`assets/hero/hero-video-loop.mp4`). Faltam poster e versões comprimidas (ver `assets/hero/README.md`). |
| Screenshots reais | 7 existem. Faltam telas importantes: lista e criação de simulação, relatório de avaliação, configurações de provedores, linha do tempo e evidências do lote, auditoria e retornos comerciais (ver `screenshots/README.md`). |
| Logo | **Falta.** A marca atual é um ícone Font Awesome (`fa-bolt`) com o texto "LeadPulse". Não há arquivo de logo. |
| Favicon / ícone | **Falta.** O ícone em `public/` é placeholder do Rails. |
| Imagem OpenGraph da nova landing | **Falta.** A atual é um recorte de Analytics em tema claro. |
| Paleta e tipografia da landing | Tokens existentes documentados em `assets/brand/README.md`. A paleta final da landing ainda não foi definida. |

## Como adicionar materiais

**Screenshots**: capture a tela real com dados fictícios de demonstração, salve em `screenshots/` como `NN-area-descricao-LARGURA.png` (ou `.webp`) e registre a linha no inventário de `screenshots/README.md` (origem, data, tema, branch). Siga o checklist de captura desse README.

**Logo**: coloque os arquivos em `assets/brand/` (SVG primeiro; PNG só como derivado) com os nomes sugeridos em `assets/brand/README.md` e atualize a tabela de status desse README.

**Referências**: coloque a imagem em `references/` com nome descritivo e escreva no `references/README.md` o que deve ser aproveitado dela e o que não deve.

## Próximo passo

Entregar este diretório ao GPT-6 Astra e pedir que comece por `docs/ASTRA_HANDOFF.md`. O Astra deve analisar o material e apresentar um plano para aprovação **antes** de escrever qualquer código.
