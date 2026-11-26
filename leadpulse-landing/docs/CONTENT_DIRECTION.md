# Direção de conteúdo — LeadPulse

São recomendações, não layout final. A estrutura, a ordem e o texto definitivos são propostas do Astra, sujeitas a aprovação.

## Posicionamento

> O LeadPulse é a camada que transforma ligações em processos: a empresa define o fluxo, a IA conduz a conversa e cada resultado fica registrado, auditável e pronto para os sistemas da empresa.

Percepção desejada: **B2B SaaS premium, tecnologia empresarial séria.** Transmitir profissionalismo, confiança, inteligência, automação, controle, escala, flexibilidade, integração e confiabilidade.

O LeadPulse **não** é:

- um chatbot de voz;
- um validador cadastral;
- uma ferramenta de CNPJ ou de fornecedores;
- um brinquedo para testar agentes;
- um projeto acadêmico.

## Tom

- Seguro e calmo. A tecnologia é impressionante, o texto não precisa gritar.
- Concreto: verbos de operação (ligar, perguntar, registrar, revisar, integrar).
- Curto: títulos de 3 a 8 palavras, parágrafos de 1 a 3 frases.
- Honesto: o futuro aparece como futuro.
- Português do Brasil.

## Narrativa sugerida

1. **Problema**: processos por telefone são repetitivos, caros e invisíveis.
2. **Ideia**: e se cada ligação seguisse um processo definido pela empresa?
3. **Como funciona**: o workflow define etapas e regras; a IA conversa; o resultado é registrado com evidência.
4. **Prova**: telas reais. Conversa, simulação, avaliação, resultados, auditoria.
5. **Confiança**: testes antes da produção, revisão humana, LGPD, transparência na chamada.
6. **Integração**: API e dados para os sistemas da empresa; tecnologia sem dependência de um único fornecedor.
7. **Flexibilidade**: um motor, muitos processos. O primeiro workflow é a validação de fornecedores.
8. **Visão**: Custom Workflows e ações em sistemas externos, identificados como próximos passos.
9. **CTA**.

O caso de fornecedores aparece como **exemplo concreto e prova de funcionamento**, não como definição do produto.

## Mensagens desejadas

- "Crie o fluxo. A IA conduz a conversa."
- "Transforme conversas em processos."
- A voz é a interface; o valor está no processo.
- Cada resposta vira um dado ligado à pergunta que a originou.
- Teste o agente em simulação antes de ligar para pessoas reais.
- Uma pessoa pode revisar e corrigir qualquer resultado.
- A chamada se identifica e respeita a recusa.
- Use as suas próprias contas de telefonia e IA (verdade hoje: Twilio e OpenAI por empresa).
- Um motor, muitos processos.

## Mensagens proibidas

- "Revolucionário", "disruptivo", "o futuro chegou", "IA que faz tudo".
- "Substitua seus atendentes", "elimine sua equipe".
- "100% preciso", "sem erros", "nunca falha".
- Atendimento 24/7 como recurso entregue (não há operação, nem ligação inbound, comprovada para isso).
- Métricas de desempenho, economia ou ROI (não há medição real publicada; os números das telas são de demonstração).
- Clientes, cases, depoimentos ou logos de empresas (não existem).
- "Parceiro oficial" de OpenAI, Twilio, Meta ou qualquer empresa.
- Linguagem de TCC: "experimento", "hipótese", "prova de conceito", "banca".
- Nomes internos: "Confaith", `api_confaith_ai`.

## Claims: o que pode e o que não pode ser dito

| Pode dizer (CURRENT) | Só como visão ("em desenvolvimento", "próximos passos") | Não dizer |
| --- | --- | --- |
| Ligações automatizadas com IA por voz em tempo real | Crie seus próprios workflows | Qualquer cliente cria qualquer fluxo hoje |
| Workflows com etapas, perguntas e regras definidas | Ações em CRM, ERP, TMS e agenda durante a conversa | Integração nativa com Salesforce, HubSpot, SAP etc. |
| Transcrição, gravação opcional e evidência por pergunta | Transferência para atendente humano | Transferência para humano disponível |
| Revisão humana dos resultados | Ligações de entrada (inbound) | Atendimento receptivo pronto |
| Simulação IA × IA com cenários e avaliação automática | WhatsApp como canal de continuidade | WhatsApp disponível em produção |
| Analytics e API de BI | Testar falando pelo navegador; ligação de teste | Teste por voz no navegador disponível |
| API REST para enviar lotes e consultar resultados | Escolha entre vários provedores de IA e telefonia | Funciona com qualquer provedor |
| LGPD: base legal, retenção, anonimização, recusa | Modelos self-hosted como modelo principal de conversa | Roda 100% on-premise |
| Multiempresa com equipe e papéis | Aprovação de workflow antes da produção | — |
| Fallback por e-mail quando a ligação não é atendida | — | — |
| Conta com credenciais próprias de Twilio e OpenAI | — | — |

Regra prática: para cada frase, alguém deve conseguir apontar a tela ou o arquivo que a comprova (`PRODUCT_VISION.md`, seção 3). Se não conseguir, a frase vai para a coluna do meio, com marcação visual de visão, ou sai da página.

## Seções possíveis

Lista de candidatas, sem ordem final:

| Seção | Conteúdo | Material |
| --- | --- | --- |
| Hero | Mensagem central, subtítulo, CTA | `assets/hero/hero-video-loop.mp4` |
| Produto logo após o hero | Uma tela real em destaque | `screenshots/01` ou `02` (simulação) |
| Problema | Dores de processos por telefone | `AUDIENCE.md` |
| Como funciona | Workflow → conversa → resultado → sistema | diagrama simples, não UI falsa |
| A conversa que segue o processo | IA com trilhos: perguntas oficiais, regras, evidência | `screenshots/05` |
| Teste antes de ligar | Simulação, cenários, avaliação | `screenshots/01–03` e telas que faltam |
| Resultados rastreáveis | Status, lote, auditoria, Analytics | `screenshots/04`, `06` |
| Um motor, muitos processos | Exemplos de workflows (existentes x visão) | `PRODUCT_VISION.md` §4.3 |
| Integração e ecossistema | API, BI, provedores, camada agnóstica | `TECHNOLOGY_ECOSYSTEM.md` |
| Confiança e LGPD | Transparência na chamada, recusa, retenção, isolamento | `PRODUCT_VISION.md` §3.4 |
| Para equipes técnicas | API, OpenAPI, autenticação, idempotência | página `/for-devs` do app |
| Roadmap e visão | Custom Workflows, tools, inbound, WhatsApp, multi-provedor | marcado como visão |
| FAQ | Objeções de `AUDIENCE.md` | — |
| CTA final | — | — |

## Headlines possíveis

Opções de partida. O Astra pode propor outras.

- Crie o fluxo. A IA conduz a conversa.
- Transforme conversas em processos.
- Workflows inteligentes. Conversas naturais. Ações reais.
- A camada inteligente para operações por voz.
- Automatize processos empresariais com IA conversacional.
- Conecte conversas aos seus processos.
- Cada ligação, um processo com resultado.

Cuidado: "Crie o fluxo" e "Ações reais" descrevem a visão. Se forem usadas no hero, o subtítulo ou a seção seguinte precisam deixar claro o que já funciona. Exemplo de subtítulo verdadeiro: "Defina etapas, perguntas e regras. O LeadPulse liga, conduz a conversa por voz e entrega cada resultado com evidência." Ainda assim, confirme com o usuário se "defina" é aceitável enquanto os workflows são configurados pela equipe do LeadPulse.

Subtítulos e selos possíveis: "IA conversacional por voz para processos empresariais" · "Teste antes de ligar" · "Evidência em cada resposta" · "Humano no controle".

## CTAs possíveis

Situação comercial verificada:

- A landing atual oferece **"Criar conta grátis"** e **"Entrar"** (cadastro self-service via Devise).
- Os planos estão **em definição**. Não há preço público.
- Hoje, as chamadas usam as contas Twilio e OpenAI da própria empresa, com os custos de cada provedor.
- **Não existe** formulário de contato, demonstração ou lista de espera no código.

| CTA | Exige |
| --- | --- |
| Criar conta | já existe (`/users/sign_up`) |
| Entrar | já existe (`/users/sign_in`) |
| Falar com a equipe / Solicitar demonstração | definir canal (e-mail, formulário, agenda) — decisão do usuário |
| Ver como funciona | âncora interna |
| Documentação para desenvolvedores | já existe (`/for-devs`) |
| Entrar na lista de acesso antecipado (Custom Workflows) | criar captação — decisão do usuário |

Para B2B premium, o CTA principal costuma ser conversa com a equipe, e o secundário, criar conta. **A escolha é do usuário.** O Astra deve perguntar antes de definir.

## Direção comercial

- Vender processo e controle, não "IA".
- Começar pelo problema operacional e terminar na arquitetura.
- Mostrar o produto real cedo.
- Ser explícito sobre o que é visão: transmite maturidade, não fraqueza.
- Não inventar prova social. Sem clientes, mostrar a prova técnica: simulação, avaliação, evidência, LGPD.

## Direção visual

**Desejada**: premium, enterprise SaaS, escura; grafite e navy profundo com ciano discreto; minimalista, sofisticada, alto acabamento.

**Evitar**: cyberpunk, neon exagerado, dashboards falsos, personagens, robôs, hologramas, cérebros digitais, estética gamer, excesso de partículas e de brilho.

Recomendações:

- **Paleta**: partir dos tokens escuros da sala de voz (`assets/brand/README.md`): fundo `#080f1b`, superfícies `#0e1827`, bordas `#263549`, ciano `#55c4ed`. Um acento só. Decidir se o laranja do símbolo atual permanece.
- **Tipografia**: Inter (já usada no produto) ou equivalente sóbria; JetBrains Mono só para detalhes técnicos (códigos, eventos). Títulos grandes com espaçamento fechado, como na referência.
- **Profundidade**: gradientes radiais suaves e bordas de 1 px. Brilho só como acento pontual. A memória de UI do projeto pede maturidade de B2B SaaS: sem card dentro de card, sem raios exagerados, sem glassmorphism decorativo.
- **Imagens**: telas reais, enquadradas com cuidado (moldura, sombra leve, recorte), sempre com indicação de dados de demonstração quando houver números visíveis, como a landing atual já faz ("Tela real do LeadPulse · dados de demonstração").
- **Movimento**: o vídeo do hero já é o movimento principal. Fora dele, animação mínima, sempre respeitando `prefers-reduced-motion`.
- **Diagramas**: para workflow e arquitetura, diagramas lineares e simples, coerentes com o grafo do vídeo, em vez de interfaces ilustrativas.
- **Acessibilidade**: contraste AA sobre o vídeo e sobre os gradientes; texto nunca embutido em imagem.
- **Marcas de terceiros**: ver `TECHNOLOGY_ECOSYSTEM.md`, seção "Integração vs parceria". Na dúvida, nome em texto, sem logo.
