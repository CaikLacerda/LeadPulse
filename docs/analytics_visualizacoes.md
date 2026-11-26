# Analytics: visualizações, 3D e catálogo de evolução

Este documento define como o LeadPulse escolhe e constrói gráficos no Analytics, com atenção especial ao 3D. Também registra quais visualizações existem, quais esperam dados e por quê. Os números citados foram medidos na base local em 27/09/2026.

## 1. Regra do produto

| Camada | Papel | Onde está |
|---|---|---|
| 2D | Leitura principal. Toda pergunta essencial é respondida aqui. | ECharts (SVG), `analytics_chart_options.js` |
| 3D | Exploração avançada, opcional, sobre os mesmos dados do 2D. | ECharts GL (WebGL), só no desktop |
| Tabela | Valor preciso e acessível. Existe para todo gráfico, inclusive sem JavaScript. | `_chart.html.erb` |

Consequências:

- Nenhuma informação existe só no 3D. O 3D recebe exatamente os mesmos dados do 2D (mesmo `data-analytics-chart-data-value`), calculados no servidor.
- Nenhum cálculo é feito no JavaScript. O servidor entrega valores, faixas, percentis e textos prontos; o navegador só desenha.
- 3D só entra quando uma terceira dimensão ajuda a ver concentração, distribuição, correlação, comportamento temporal, geografia, performance ou anomalias. Não usamos pizza 3D, KPI 3D, funil 3D, tabela 3D nem barras 3D decorativas.

## 2. Linguagem visual por página

| Página | Composição | Pergunta principal |
|---|---|---|
| Visão geral | Colunas empilhadas no tempo + composição por resultado + funil operacional | Quanto foi validado e onde o fluxo perde volume? |
| Chamadas | Linha do tempo + mapa de calor dia × hora (2D/3D) + distribuição de duração | Quando ligar e quanto duram as chamadas atendidas? |
| Qualificação | Funil comercial + composição por resultado + origem + segmentos | Quantos fornecedores viram oportunidade, e por quê não? |
| Lotes | Distribuição do processamento (com cauda longa) + resumo de extremos + tabela analítica | Quais lotes estão fora do padrão? |
| Busca de fornecedores | Futuro mapa geográfico (seção 6.2) | Onde estão os fornecedores encontrados? |

## 3. Regras para qualquer visualização 3D

| # | Regra | Como está garantido hoje |
|---|---|---|
| 1 | Alternativa 2D equivalente | O seletor começa no 2D; o 3D usa os mesmos dados. |
| 2 | Desktop-first | Seletor só aparece com `(min-width: 1024px)`. |
| 3 | Não obrigatório abaixo de 1024 px | CSS esconde o seletor e o controller volta ao 2D ao estreitar a janela. |
| 4 | Detectar WebGL | `supportsWebGL()` testa uma vez por página e libera o contexto de teste. |
| 5 | Fallback automático | Sem WebGL, ou se o ECharts GL falhar ao baixar, o seletor some e o 2D segue. |
| 6 | Lazy loading | `pin "echarts-gl", preload: false`; `import("echarts-gl")` só no primeiro clique em 3D. |
| 7 | GL só quando necessário | Nenhuma página baixa o GL antes do clique (verificado pelas requisições). |
| 8 | Sem autoplay de câmera | `autoRotate: false`. |
| 9 | Limites de rotação | Elevação de 10° a 45°, giro de −20° a 30°, distância fixa (sem zoom nem pan). |
| 10 | Redefinir câmera | Botão "Redefinir câmera", visível só no 3D. |
| 11 | Tooltip completo | Mesmo tooltip do 2D: tentativas, atendidas, taxa, amostra e aviso de baixa amostra. |
| 12 | Clique navega | Clique numa barra abre as tentativas da célula (`/analytics/tentativas?dia_semana=…&hora=…`). |
| 13 | Nada exclusivo do 3D | A tabela e o 2D trazem tudo o que o 3D mostra. |
| 14 | `prefers-reduced-motion` | Sem animação de câmera, de barras nem de transição. |
| 15 | Tema claro e escuro | Cores lidas dos tokens CSS a cada desenho; troca de tema redesenha. |
| 16 | Não bloquear o scroll | A roda do mouse não chega ao GL (que sempre cancela o evento); a página rola. |
| 17 | Nada sensível no tooltip | Só agregados por célula; sem nomes, telefones ou gravações. |
| 18 | Performance medida | Seção 5. |
| 19 | Acessibilidade | O canvas tem `role="img"` com resumo; a tabela é a versão acessível; a legenda é `aria-hidden`. |
| 20 | Sem perspectiva enganosa | Distância fixa e ângulos limitados; a altura nunca é a única pista (cor e tooltip repetem o valor). |

## 4. Seletor de visualização padrão

Todo gráfico com mais de uma representação usa os mesmos controles, com o visual do design system (não os controles nativos do ECharts):

```
Métrica [ Volume | Taxa ]    Visão [ 2D | 3D ]    [Redefinir câmera]    [Tabela]
```

- `analytics/_view_switch.html.erb`: grupo `[2D | 3D]` e botão de câmera. Nasce oculto; o controller mostra quando é possível.
- `analytics/_heatmap_modes.html.erb`: exemplo de métrica + visão.
- Os rótulos "Métrica" e "Visão" aparecem a partir de 1280 px; os grupos sempre têm `aria-label`.
- A legenda de escala é HTML (`.analytics-scale`), com as mesmas cores dos gráficos, e troca sozinha entre Volume e Taxa e entre 2D (hachura) e 3D (cinza).
- A troca 2D ↔ 3D não recarrega a página: some e reaparece em cerca de 200 ms. Métrica, filtros, período e URL continuam os mesmos.

Para adicionar um 3D a outro gráfico:

1. Criar o builder `<tipo>3d` em `analytics_chart_options.js`, reaproveitando o tooltip do 2D.
2. Tratar o clique em `drillTarget`.
3. Renderizar `analytics/view_switch` nos controles do gráfico e passar `note_3d`.

O controller cuida de download, fallback, câmera, roda do mouse e liberação do WebGL.

## 5. Performance do 3D (medida)

Ambiente: Chromium headless com WebGL por software (SwiftShader), servidor local. Numa GPU real os tempos de desenho são menores.

| Item | Resultado |
|---|---|
| ECharts completo (só páginas do Analytics) | 1.121.883 B; 367.915 B com gzip |
| ECharts GL (só no clique em 3D) | 639.846 B; 175.203 B com gzip |
| Primeiro 3D (download do GL + inicialização) | 244–280 ms |
| Trocas seguintes 2D ↔ 3D | ~200 ms, incluindo a transição |
| Memória (heap JS) | 12,3 MB → 13,7 → 14,0 → 14,2 MB após 20, 40 e 60 alternâncias: estabiliza, sem vazamento |
| Contextos WebGL | Criados = liberados (25/25) após alternâncias, troca de tema, resize, navegação Turbo, histórico e estreitamento da janela |
| Navegação Turbo com 3D ativo | O contexto é liberado ao sair; ao voltar pelo histórico, o gráfico reabre no 2D |
| Console | Sem erros nem avisos |

O ECharts GL não devolve o contexto WebGL no `dispose()`. O controller perde o contexto explicitamente (`WEBGL_lose_context`), porque o navegador mantém só cerca de 16 contextos ativos.

## 6. Análise dos novos 3D

Cada proposta foi avaliada pelos dez critérios combinados: pergunta, dados necessários, dados existentes, amostra, dimensionalidade, ganho sobre o 2D, custo, performance, alternativa 2D e decisão.

### 6.1 Superfície 3D de performance temporal (hora × dia × taxa)

- **Pergunta:** quais faixas horárias são consistentemente melhores ou piores?
- **Dados necessários:** taxa de atendimento por dia da semana e hora, com amostra suficiente em células vizinhas.
- **Dados existentes:**
  - 90 dias: 61 tentativas em 9 células.
  - 12 meses: 63 tentativas em 11 células, 56 delas numa sexta-feira.
  - Nenhuma célula chega a 20 tentativas (máximo 16).
- **Dimensionalidade:** o dia da semana é categórico. Uma superfície contínua entre "terça" e "quarta", ou entre horas sem dado, inventaria valores intermediários.
- **Ganho sobre o 2D:**
  - Hoje nenhum: o mapa de calor e as barras 3D já mostram exatamente as células medidas.
  - Uma superfície sem interpolação seria idêntica às barras 3D.
- **Custo e performance:** baixos, com a mesma infraestrutura do GL.
- **Alternativa 2D:** mapa de calor com taxa e hachura de baixa amostra (já existe).
- **Decisão:** **aguardar mais dados.** Reavaliar quando houver pelo menos 3 dias com 6 ou mais horas seguidas de n ≥ 20. Mesmo assim, sem interpolar entre dias da semana; se houver interpolação entre horas, ela deve ser declarada na legenda.

### 6.2 Mapa 3D de fornecedores (Brasil → estado → região → cidade)

- **Pergunta:** onde se concentram os fornecedores encontrados e os qualificados?
- **Dados necessários:**
  - localização confiável por fornecedor;
  - ligação entre fornecedor encontrado e resultado da validação ou qualificação;
  - malha geográfica do Brasil (nova dependência).
- **Dados existentes:**
  - 14 buscas com 77 fornecedores no `response_payload` da API de busca.
  - 70 dos 77 têm latitude e longitude vindas da própria API; nada é deduzido pelo LeadPulse.
  - Precisão (`location_precision`): 18 no nível de rua ou endereço (OpenStreetMap), 24 "aproximada" e 35 sem informação. Só 23% são confiáveis para um mapa de pontos.
  - A UF vem em todos os 77, mas concentrada: SP 56, CE 10, PR 5, AC 4, RO 2. São 20 cidades.
  - A coluna `region` da busca é texto livre e mistura cidade e estado ("Campinas", "Paraná", "São paulo"/"São Paulo").
  - Não existe ligação direta entre o fornecedor da busca e o registro validado. Seria preciso casar pelo lote importado (`import_metadata.supplier_discovery_search_id`) e pelo telefone, o que é regra nova.
- **Ganho sobre o 2D:** com 5 UFs e 77 pontos, uma lista ordenada por UF responde melhor que um mapa.
- **Custo:**
  - Malha do IBGE (dado público) simplificada, de 100 a 600 KB.
  - Eixo de navegação estado → cidade.
  - Regra de ligação fornecedor → resultado.
  - Nenhum serviço de geocoding: não foi adicionado e não deve ser sem aprovação.
- **Alternativa 2D:** barras por UF ou cidade, e futuramente mapa coroplético por UF.
- **Decisão:** **aguardar mais dados.** Reavaliar com pelo menos 500 fornecedores com precisão de rua ou endereço, pelo menos 10 UFs com 20 ou mais fornecedores cada, e a regra de ligação com o resultado aprovada.

### 6.3 Scatter 3D de lotes (registros × processamento × taxa de confirmação)

- **Pergunta:** quais lotes fogem do padrão (muito volume com processamento alto; processamento alto com baixa confirmação)?
- **Dados existentes:**
  - 58 lotes em 12 meses, com 0, 1 ou 2 registros (12, 16 e 30 lotes).
  - Taxa de confirmação por lote com n ≤ 2: só 0%, 50% ou 100%.
  - Processamento medido em 42 lotes, com cauda longa (3 lotes de cerca de 96 dias).
- **Dimensionalidade:** o eixo de registros praticamente não varia e a taxa é degenerada. Dois dos três eixos não carregam informação.
- **Ganho sobre o 2D:** nenhum hoje. A distribuição com cauda e o resumo de extremos já mostram os lotes fora do padrão.
- **Alternativa 2D:** histograma com cauda longa, painel "Resumo do processamento" (mais rápido, mais lento, acima de 1 dia) e tabela ordenável por processamento (já existem).
- **Decisão:** **aguardar mais dados.** Não exibir seletor 3D inútil. Reavaliar com pelo menos 30 lotes de 20 ou mais registros terminais cada e variação real de tamanho (p90/p10 de registros ≥ 5). Comparar antes com um scatter 2D (registros × processamento, cor = taxa); o 3D só se justifica se as três dimensões forem necessárias ao mesmo tempo.

### 6.4 Qualificação: segmento × período × taxa ou volume

- **Pergunta:** que segmentos crescem, perdem performance ou têm sazonalidade?
- **Dados existentes:**
  - 5 segmentos buscados em 14 buscas (Malha de ferro 7, Adubo 3, Madeira 2, Banana 1, Ferro 1).
  - 13 oportunidades em 2 segmentos (Adubo 11, Malha de ferro 2).
- **Ganho sobre o 2D:** nenhum com essa amostra. A tabela "Segmentos buscados" já responde.
- **Alternativa 2D:**
  - Futuramente, linhas pequenas por segmento (*small multiples*) ou mapa de calor segmento × mês.
  - Treemap quando houver muitos segmentos.
- **Decisão:** **aguardar mais dados.** Reavaliar com pelo menos 5 segmentos, cada um com 20 ou mais registros qualificados, ao longo de 6 ou mais períodos.

### 6.5 Mapa 3D de oportunidades (região × segmento × oportunidades)

- **Pergunta:** onde estão as melhores oportunidades comerciais?
- **Dados existentes:**
  - `commercial_opportunities` tem segmento, mas não tem região.
  - A região só existe na busca, em texto livre.
  - 13 oportunidades, 6 coletas concluídas.
- **Decisão:** **futuro.** Pré-requisitos:
  - região normalizada (UF/IBGE) gravada na oportunidade ou derivada de forma auditável;
  - volume comercial;
  - a evolução do módulo comercial.
- **Alternativa 2D prevista:** mapa de calor região × segmento, com o 3D como camada exploratória do mesmo dado.

### 6.6 Workflows: etapa × workflow/versão × execuções, conversão ou abandono

- **Pergunta:** que etapa mais perde conversas, que versão converte melhor e onde está o gargalo?
- **Estado:** não há entidade de Workflow; o Workflow Builder ainda está em planejamento.
- **Decisão:** **futuro.** Nada foi implementado nem alterado no schema.
- **Premissas para a arquitetura:**
  - execução por nó com timestamps;
  - versão do workflow;
  - resultado por nó (seguiu, abandonou, erro).
- **2D previsto:** funil por versão e mapa de calor nó × versão.
- **3D possível:** barras 3D nó × versão, com o mesmo seletor e as mesmas regras da seção 3.

## 7. Catálogo

| Visualização | Dados necessários | Estado atual dos dados | Viável agora? | Página | Objetivo | Estado |
|---|---|---|---|---|---|---|
| Chamadas dia × hora 3D | Tentativas por dia/hora com início próprio | 63 tentativas em 11 células (12 m); todas de baixa amostra na taxa | Sim, como exploração do 2D | Chamadas | Concentração de volume e atendimento por horário | IMPLEMENTADO |
| Superfície temporal 3D | Taxa por dia/hora com n ≥ 20 em células vizinhas | Nenhuma célula com n ≥ 20 | Não | Chamadas | Picos, vales e faixas consistentes | AGUARDANDO DADOS |
| Mapa geográfico de fornecedores | Localização precisa + ligação com resultado + malha do Brasil | 77 fornecedores, 23% com precisão de rua; 5 UFs; sem ligação | Não | Busca de fornecedores | Concentração geográfica e qualificação por região | AGUARDANDO DADOS |
| Scatter 3D de lotes | Lotes com tamanho variado e taxa com amostra | Lotes de 0–2 registros; taxa 0/50/100% | Não | Lotes | Lotes fora do padrão | AGUARDANDO DADOS |
| Segmentos × período × qualificação | Segmentos com volume ao longo do tempo | 5 segmentos em 14 buscas | Não | Qualificação | Tendência e sazonalidade por segmento | AGUARDANDO DADOS |
| Mapa de oportunidades | Região normalizada nas oportunidades | Sem região; 13 oportunidades | Não | Comercial | Onde estão as melhores oportunidades | FUTURO |
| Workflow × nó × conversão | Entidade Workflow com execução por nó | Inexistente | Não | Workflows | Abandono, versão e gargalo | FUTURO |

Visualizações "AGUARDANDO DADOS" ou "FUTURO" não são implementadas nem ficam escondidas no código. Quando o gatilho for atingido, a proposta volta para esta análise antes de qualquer código.

## 8. Histogramas e cauda longa

- As faixas ficam no servidor (`BatchesQuery::PROCESSING_BINS`, `AttemptsQuery::DURATION_BINS`), em escala de tempo humana e quase logarítmica. Poucos lotes de dias ou meses não achatam a leitura dos que levam minutos.
- A última faixa do processamento ("> 1 dia") é a cauda longa. Ela aparece hachurada, com o rótulo "Cauda longa" e o eixo em destaque, e o painel "Resumo do processamento" mostra quantos lotes há nela e qual é o mais lento.
- Mediana e p90 são calculados no SQL sobre os valores exatos (`percentile_cont`). O gráfico só indica em que faixa cada um cai. Por interpolação, a mediana pode cair numa faixa vazia: por exemplo, com duas chamadas de 20 s e 92 s, a mediana é 56 s e cai na faixa 30–60 s, que não tem nenhuma chamada. A etiqueta mostra o valor para deixar isso explícito.
- Não usamos escala logarítmica no eixo de contagem nem eixo quebrado. As contagens são pequenas, e as faixas desiguais, declaradas na nota do gráfico, resolvem a distorção sem esconder valores.
