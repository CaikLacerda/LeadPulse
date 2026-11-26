# Handoff para o GPT-6 Astra — landing page do LeadPulse

Este é o ponto de entrada. Leia este documento inteiro, depois os demais arquivos de `docs/` e os READMEs das pastas de assets.

Preparado em 15/10/2026. Os itens marcados como **CURRENT** foram conferidos no código. A legenda (CURRENT, PARTIAL, PLANNED, EVALUATED, OPTIONAL, FUTURE) está em `BRIEF.md`.

## 1. O que é o LeadPulse

Plataforma B2B de IA conversacional por voz para processos empresariais. A empresa tem um processo feito por telefone; o LeadPulse liga, conduz a conversa seguindo um workflow, coleta e classifica as respostas, registra evidências e entrega o resultado para revisão e para os sistemas da empresa.

Mensagem central: **"Crie o fluxo. A IA conduz a conversa."** A headline final ainda não foi escolhida.

## 2. Visão atual (o que existe)

- Ligações de saída com Twilio e OpenAI Realtime, usando as contas da própria empresa.
- Três workflows **predefinidos em código**: validação cadastral, validação de fornecedor por segmento (`supplier_validation`, o caso de origem no TCC) e retorno comercial.
- Agente com trilhos: perguntas obrigatórias em fala exata (TTS), regras locais, intérprete local Qwen para respostas ambíguas, evidência por pergunta.
- Lotes por planilha ou API, tentativas, transcrição, gravação opcional, fallback por e-mail, exportação.
- Auditoria com revisão humana, Analytics, API de BI, LGPD, multiempresa.
- Ambiente de Simulação IA × IA: 15 cenários com gabarito, avaliação por campo, baterias, eventos e áudio ao vivo.

Detalhes e evidências: `PRODUCT_VISION.md`, seção 3.

## 3. Visão futura

Custom Workflows criados pela empresa: etapas, perguntas, dados, decisões, condições, ramos, tools e APIs, ações, webhooks, fallback, transferência para humano e encerramento. Simulação de qualquer workflow antes da produção. Ligações de entrada. WhatsApp como canal de continuidade. Camadas intercambiáveis de IA, telefonia e mensageria. Ver `PRODUCT_VISION.md`, seções 4 a 7.

## 4. Público

Empresas, sobretudo pequenas e médias, com processos repetitivos ou de alto volume por telefone: atendimento, suporte, comercial, cobrança, operações, logística, saúde e serviços. Decisores de negócio primeiro (operações, atendimento, comercial, cobrança, inovação); decisores técnicos depois (CTO, tecnologia, integração). Ver `AUDIENCE.md`.

## 5. Proposta de valor

Transformar ligações em processos configuráveis, executáveis e observáveis. A voz é a interface. O valor está na ligação entre conversa, inteligência, workflow, dados e sistemas, com evidência em cada resultado e testes antes da produção.

## 6. Tecnologias

**CURRENT**: Rails 8.1 (Hotwire, Tailwind 4, Devise, Solid Queue), FastAPI, PostgreSQL, Amazon SQS, AWS, WebSockets, OpenAI (Realtime, transcrição, TTS, Responses com web search e saída estruturada), Qwen `qwen3:1.7b` via Ollama (só como intérprete auxiliar), Twilio Voice e Media Streams, SMTP, BrasilAPI, OpenStreetMap.

**PARTIAL**: Meta WhatsApp Cloud API (só no fluxo de teste local), GPT-Live (experimental), app Flutter (protótipo).

**FUTURE**: tool calling, conectores de sistemas, webhooks de saída, inbound, transferência, Qwen ou outros modelos como modelo principal, outros provedores de telefonia e mensageria.

Tabela completa: `TECHNOLOGY_ECOSYSTEM.md`, seção 9.

## 7. Integrações

- **Hoje**: API REST para sistemas externos enviarem lotes e lerem resultados e evidências (Bearer por empresa, idempotência); API de simulações; API de BI; OpenAPI; página `/for-devs`.
- **Visão**: ações durante a conversa em CRM, ERP, TMS, agenda e tickets.
- **Nenhuma parceria oficial** com OpenAI, Twilio, Meta ou qualquer empresa. Use "integração com", nunca "parceiro". Ver `TECHNOLOGY_ECOSYSTEM.md`, seção 10.

## 8. Localização dos assets

| O quê | Onde | Situação |
| --- | --- | --- |
| Marca | `assets/brand/README.md` | **Sem logo.** Marca atual: ícone Font Awesome `fa-bolt` + texto "LeadPulse". Tokens de cor e fonte documentados. |
| Vídeo do hero | `assets/hero/` | existe |
| Referência visual | `references/` | existe |
| Screenshots | `screenshots/` | 7 existem, várias telas faltam |

## 9. Referência visual

`references/landing-reference.jpg`: landing escura de um produto fictício ("Agex"). Use para composição, hierarquia, ritmo, espaçamento, produto logo após o hero, tipografia, profundidade e organização das seções. **Não copie**: texto, marca, faixa de logos "Trusted by", dashboards ilustrativos, azul saturado e partículas. Ver `references/README.md`.

`references/current-leadpulse-site/` mostra a landing pública que já existe no app Rails, com o posicionamento antigo ("Encontre empresas. Valide por voz."). É contexto, não modelo.

## 10. Vídeo do hero

`assets/hero/hero-video-loop.mp4`: 1920×1080, 8 s, 30 fps, H.264, sem áudio, 22,7 MB. Voz à esquerda, workflow à direita, centro limpo para o conteúdo. Uso futuro como fundo do hero (`autoplay muted loop playsinline`, poster, reduced motion). Pontos abertos: peso do arquivo, enquadramento no mobile, emenda do loop. Quadros para análise em `assets/hero/frames/`. Ver `assets/hero/README.md`.

## 11. Screenshots

Em `screenshots/`, todas com dados fictícios:

- `01`–`03`: simulação ao vivo, tema escuro. Render offline da view real; versão visual ainda não commitada; fonte de fallback. Recapturar antes de produção.
- `04`: Analytics, tema claro.
- `05`: conversa com revisão humana, tema claro.
- `06`: registros do lote, tema claro.
- `07`: busca de fornecedores, tema claro.

Faltam: lista e criação de simulação, resultado com avaliação, configurações de provedores, linha do tempo e evidências, auditoria, retornos comerciais. Inventário e checklist em `screenshots/README.md`.

## 12. Restrições

1. Telas reais em vez de UI fictícia. Sem mockups gerados por IA.
2. Nenhum recurso FUTURE apresentado como pronto.
3. Não limitar o LeadPulse a fornecedores, a CNPJ ou a validação cadastral.
4. Sem linguagem acadêmica nem menção a TCC voltada a clientes.
5. Sem métricas de desempenho, ROI ou economia: não há medição real publicada; os números das telas são de demonstração.
6. Sem clientes, depoimentos ou logos de empresas: não existem.
7. Sem "parceiro oficial". Logos de terceiros só com as três condições de `TECHNOLOGY_ECOSYSTEM.md` §10.
8. Sem nomes internos ("Confaith", `api_confaith_ai`).
9. Não editar o vídeo original nem os arquivos do projeto principal.
10. Não alterar a landing pública existente no app Rails sem decisão explícita do usuário.

## 13. Direção visual

Premium, enterprise SaaS, escura: grafite, navy profundo, ciano discreto, minimalista e sofisticada. Base de tokens: sala de voz da simulação (`#080f1b`, `#0e1827`, `#263549`, `#55c4ed`). Tipografia Inter e JetBrains Mono. Evitar cyberpunk, neon, robôs, cérebros, hologramas, estética gamer, partículas e dashboards falsos. Ver `CONTENT_DIRECTION.md`, seção "Direção visual".

## 14. CURRENT vs FUTURE

| CURRENT | FUTURE / PLANNED |
| --- | --- |
| Workflows predefinidos (3) | Custom Workflows criados pela empresa |
| Ligação de saída | Inbound; transferência para humano |
| Fallback por e-mail | Fallback por regra do workflow, incluindo WhatsApp (hoje PARTIAL) |
| API REST de entrada; API de BI | Tools e ações em sistemas durante a conversa; webhooks |
| Simulação IA × IA de `supplier_validation` | Microfone no navegador, ligação de teste, qualquer workflow, aprovação para produção |
| OpenAI + Qwen auxiliar; contas próprias por empresa | Camadas de provedores intercambiáveis; self-hosted como modelo principal |
| Evidência, revisão humana, Analytics, LGPD | Observabilidade por workflow e por etapa |

Matriz completa de claims: `CONTENT_DIRECTION.md`, seção "Claims".

## 15. Próximos passos

### Decisões que o usuário precisa tomar (pergunte antes de assumir)

1. **CTA principal**: "Criar conta" (já existe) ou "Falar com a equipe / Solicitar demonstração" (não há canal no código). Qual canal?
2. **Onde a landing vai viver**: substituir a landing pública do Rails (`app/views/pages/_public_landing.html.erb`) ou ser um site separado?
3. **Logo**: criar um logo próprio ou manter o ícone de raio provisoriamente?
4. **Acento de cor**: ciano (sala de voz), azul (workspace) ou laranja (símbolo atual)?
5. **Telas faltantes**: capturar antes do plano final? Quais?
6. **Uso de "Crie o fluxo"** no hero enquanto os workflows ainda são predefinidos: aceitável com subtítulo de contexto?
7. **Seção de visão/roadmap**: mostrar publicamente os recursos futuros?
8. **Idioma**: só português ou também inglês?

### Material de origem (somente leitura)

| Documento | Caminho |
| --- | --- |
| README do app web | `LeadPulse/README.md` |
| Guia das telas | `LeadPulse/docs/guia_telas_leadpulse.md` |
| Documentação do Rails | `LeadPulse/docs/mini_documentacao_rails.md` |
| Avaliação operacional (método, sem resultados) | `LeadPulse/docs/avaliacao_operacional.md` |
| LGPD | `LeadPulse/docs/politica_lgpd_leadpulse.md` |
| Multiempresa | `LeadPulse/docs/arquitetura_multi_tenant.md` |
| Redesign público (03/10/2026) | `LeadPulse/docs/redesign-publico/README.md` |
| Arquitetura da API | `api_confaith_ai/docs/architecture.md` |
| Ciclo da chamada | `api_confaith_ai/docs/realtime.md` |
| Simulações | `api_confaith_ai/docs/simulations.md` |
| Segurança | `api_confaith_ai/docs/security.md` |
| Manual de integração | `api_confaith_ai/docs/Manual_de_Integracao_LeadPulse_API.md` |

---

O próximo passo NÃO é começar a programar imediatamente.

O GPT-6 Astra deverá primeiro:

1. analisar todos os materiais;
2. analisar a referência visual;
3. analisar o hero video;
4. analisar screenshots reais;
5. analisar a documentação;
6. propor arquitetura completa da landing page;
7. propor narrativa;
8. propor seções;
9. propor hierarquia visual;
10. propor conteúdo;
11. apresentar um plano detalhado;
12. solicitar aprovação.

Somente depois da aprovação deverá começar a implementação.
