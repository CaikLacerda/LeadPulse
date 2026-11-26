# Visão de produto — LeadPulse

Este documento separa o que o LeadPulse **é hoje**, conferido no código em 15/10/2026, do que ele **pretende ser**. A legenda (CURRENT, PARTIAL, PLANNED, EVALUATED, OPTIONAL, FUTURE) está em `BRIEF.md`.

Repositórios analisados:

- `LeadPulse`: app web em Rails (telas, contas, lotes, Analytics, LGPD, simulações).
- `api_confaith_ai`: serviço FastAPI (ligações, IA, filas, evidências, motor de simulação). O nome é interno.

---

## 1. Origem no TCC

O projeto começou como TCC com uma pergunta prática: dá para trocar a ligação manual de qualificação de fornecedores por uma conversa com IA por voz, com resultado confiável e auditável?

O primeiro workflow, `supplier_validation`, responde a essa pergunta. Ele foi implementado de ponta a ponta: busca de fornecedores, importação do lote, ligação real, coleta de dados, classificação, evidências, revisão humana, Analytics e simulação com avaliação.

O TCC é a **origem e a prova de conceito**. A landing não deve soar acadêmica nem limitar o produto a esse caso.

## 2. O caso atual: `supplier_validation`

Definido em `api_confaith_ai/app/domain/workflows/supplier_validation.py` como um contrato de etapas e slots, em ordem fixa:

```text
1. phone_belongs          o telefone pertence à empresa?
2. supplies_segment       a empresa fornece o segmento?
3. commercial_interest    aceita um retorno comercial?
4. callback_phone_*       mesmo número ou outro? qual? confirma?
5. callback_time_*        melhor dia e horário (e período, se ambíguo)
```

Cada slot só é perguntado depois que as etapas anteriores estão resolvidas. Uma rejeição encerra as etapas seguintes. O contrato é validado na subida da aplicação: um workflow malformado falha no deploy, nunca no meio de uma ligação.

Esse formato de **etapas + slots + dependências** é a semente do conceito de workflow configurável.

## 3. O que o produto faz hoje (CURRENT)

### 3.1 Execução de ligações

| Capacidade | Evidência no código |
| --- | --- |
| Ligação de saída via Twilio, com as credenciais e números de cada empresa | `app/services/twilio_voice_service.py`, `db/models/twilio_credential.py`, `twilio_phone_number.py` |
| Conversa em tempo real: áudio da Twilio (Media Streams, WebSocket) ligado ao OpenAI Realtime | `app/services/openai_realtime_bridge.py`, `docs/realtime.md` |
| Voz, modelo, velocidade e instruções de estilo configuráveis por empresa | Rails `/configuracoes/openai`; `app/core/config.py` (`OPENAI_REALTIME_*`) |
| Detecção de fala (VAD), barge-in (o interlocutor pode interromper), reprompt em silêncio | `config.py` (`realtime_vad_*`, `barge_in`), `docs/simulations.md` |
| Aviso de chamada automatizada e respeito à recusa | tela de conversa ("Esta é uma chamada automatizada e pode ser gravada"); classe `privacy_refusal` |
| Gravação opcional da chamada, com remoção da gravação | `twilio_voice_service.py` (`Record`, `delete_recording`) |
| Tentativas, novas tentativas e prazo por chamada | `call_attempt.py`, `call_deadline.py`, `call_reconciliation.py` |
| Fallback por e-mail (SMTP) quando a ligação não é atendida | `validation_async_service.py`, `email_service.py` |

### 3.2 Fluxos predefinidos sobre o mesmo motor

| Fluxo | O que faz | Rotas da API |
| --- | --- | --- |
| Validação cadastral | Confirma se o contato pertence à empresa; consulta CNPJ na BrasilAPI | `/validations` |
| Validação de fornecedor por segmento | Workflow `supplier_validation` (seção 2) | `/supplier-validations` |
| Retorno comercial | Coleta condições comerciais (especificação do produto, preço unitário, pedido mínimo, faixas de preço por lote), normalizadas em formato estruturado | `/commercial-validations` |

Os três são código, não configuração. O cliente não cria nem altera esses fluxos.

### 3.3 Arquitetura do agente: IA com trilhos determinísticos

O agente **não** deixa toda a conversa por conta de um modelo de linguagem. A conversa combina:

1. **Modelo de voz em tempo real** (OpenAI Realtime): fala, escuta e transcreve.
2. **Falas determinísticas**: nos turnos obrigatórios cuja fala já é conhecida, o modelo generativo não participa. O texto exato é sintetizado por TTS (`gpt-4o-mini-tts`) e registrado como foi dito (`app/services/deterministic_speech.py`). Uma resposta só vale depois que a pergunta correspondente foi falada.
3. **Regras locais de resposta** (`supplier_answer_rules.py`): classificam as respostas previsíveis sem chamar um modelo.
4. **Intérprete semântico local** (Qwen `qwen3:1.7b` em Ollama, self-hosted): usado só para respostas compostas ou ambíguas.
5. **Classificação final e evidência por pergunta**: cada dado coletado fica ligado à pergunta que o originou (`question_id`).

Esse desenho é o argumento técnico mais forte de confiabilidade: **a IA conversa, o workflow controla**. Pode aparecer na landing em linguagem de negócio ("cada pergunta do processo é feita e comprovada"), sem jargão.

### 3.4 Operação, evidências e controle

| Capacidade | Onde |
| --- | --- |
| Busca de fornecedores por segmento e região, com mapa | Rails `/busca`; API com OpenAI web search; OpenStreetMap/Nominatim |
| Importação de lotes por planilha ou API (Bearer token), com versões | Rails `/dados`; API `POST /validations…` |
| Status por lote e por registro, linha do tempo, exportação XLSX/CSV | Rails `/dados/:id` |
| Conversa na ordem real, com a etapa de cada fala | tela de conversa (`screenshots/05`) |
| Revisão humana: corrigir o resultado e registrar observação | Rails `/auditoria` |
| Retornos comerciais | Rails `/comercial` |
| Analytics: visão geral, chamadas, qualificação, lotes, registros, tentativas | Rails `/analytics/*` |
| API de BI com tokens próprios | Rails `/api/v1/analytics/*`, `/configuracoes/tokens-bi` |
| LGPD: base legal, finalidade, retenção, anonimização, solicitações de titulares, operadores terceiros, trilha de auditoria | Rails `/lgpd/*`, `/configuracoes/lgpd`; API `apply_retention.py` |
| Multiempresa: contas, equipe, papéis, convites | Rails `Account`, `AccountMembership`, `/equipe` |
| Credenciais de provedores cifradas por empresa; correlação ponta a ponta (`X-Request-ID`) | API `docs/security.md`, `docs/observability.md` |

### 3.5 Ambiente de Simulação

| Capacidade | Status |
| --- | --- |
| Modo **IA × IA**: o agente de produção, com a mesma configuração da conta, conversa com uma contraparte simulada por uma segunda sessão de IA, sem telefonia | CURRENT |
| 15 cenários oficiais para `supplier_validation`: 5 favoráveis, 5 parciais, 5 difíceis, cada um com gabarito | CURRENT |
| Eventos ao vivo: estado de cada participante (ouvindo, pensando, falando), níveis de áudio, turnos | CURRENT |
| Monitor de áudio ao vivo no navegador (só escuta; microfone desligado) | CURRENT |
| Avaliação por campo: correto verificado, correto não verificado, incorreto, ausente, não aplicável | CURRENT |
| Precisão só com campos verificados (o dado precisa ter sido perguntado e respondido) | CURRENT |
| Fidelidade da contraparte: a simulação é descartada se o fornecedor simulado contradiz o gabarito | CURRENT |
| Baterias de experimento com repetições, elegibilidade e execução oficial por cenário | CURRENT |
| Reprodutibilidade: snapshot do cenário, do alvo e hash do código em cada execução | CURRENT |
| Métricas de comportamento: falas determinísticas, fallbacks de TTS, falas fora do roteiro, retries, reprompts, decisões das regras e do Qwen | CURRENT |
| Modo **conversar com o agente pelo microfone do navegador** (`browser_voice`) | PLANNED (no catálogo como indisponível) |
| Modo **receber uma ligação real de teste** (`phone_call`) | PLANNED (no catálogo como indisponível) |
| Simular um workflow criado pelo usuário (`workflow_version`) | PLANNED (previsto em comentário de `simulation_targets.py`) |
| Protocolo experimental GPT-Live | PARTIAL (opt-in experimental, com limitações documentadas) |

A avaliação é **determinística**: regras comparam o resultado ao gabarito. Não há "LLM como juiz".

**Não há resultados reais de desempenho publicáveis.** `LeadPulse/docs/avaliacao_operacional.md` define o método de comparação entre processo manual e automatizado, mas a execução com base real autorizada ainda está pendente. Os números das telas são de demonstração.

## 4. Evolução: de workflows predefinidos a uma plataforma de workflows

```text
Hoje                                    Visão
──────────────────────────────────      ──────────────────────────────────────────
3 fluxos escritos em código             workflows criados pela empresa
perguntas e etapas fixas                etapas, perguntas, condições e ramos configuráveis
classificação do resultado              decisões e ações durante a conversa
API para enviar lotes e ler resultado   tools: consultar e atualizar sistemas externos
fallback por e-mail                     fallback por regra do workflow (WhatsApp, e-mail, nova tentativa)
só ligações de saída                    saída e entrada (inbound)
simulação IA × IA de 1 workflow         simulação de qualquer workflow antes da produção
Twilio + OpenAI acoplados               camadas de provedores intercambiáveis
```

### 4.1 Conceito de workflow (FUTURE)

```text
Ligação
→ detectar contexto
→ entender intenção
→ perguntar
→ interpretar resposta
→ consultar sistema
→ aplicar regra
→ decidir
→ executar ação
→ continuar conversa
→ registrar resultado
→ finalizar
```

Mensagem: **"O usuário cria o fluxo. A IA conduz a conversa e executa o processo."**

### 4.2 Elementos de um workflow e situação atual

| Elemento | Hoje | Situação |
| --- | --- | --- |
| Etapas | Etapas fixas em código (`STEPS`) | CURRENT (fixo) / FUTURE (configurável) |
| Perguntas | Perguntas oficiais por slot, com fala determinística | CURRENT (fixo) / FUTURE (configurável) |
| Dados coletados | Slots tipados (sim/não, escolha, telefone, horário, texto) | CURRENT (fixo) |
| Validações | Telefone, CNPJ, horário, confirmação de número | CURRENT (fixo) |
| Decisões e condições | Dependência entre etapas; rejeição encerra o fluxo | CURRENT (fixo) / FUTURE (configurável) |
| Ramificações | Desdobramentos dentro de uma etapa (outro número, período) | CURRENT (limitado) / FUTURE |
| Regras | Regras locais de interpretação | CURRENT (fixo) |
| Tools / chamadas de API durante a conversa | Não há | FUTURE |
| Consultas externas | CNPJ na BrasilAPI antes da ligação | CURRENT (fixo) / FUTURE (genérico) |
| Ações e webhooks de saída | Não há webhook de saída; o Rails consulta a API | FUTURE |
| Fallback | E-mail quando a ligação não é atendida | CURRENT (e-mail) / PARTIAL (WhatsApp) |
| Transferência para humano | Não há | FUTURE |
| Encerramento | Encerramento por fim das etapas, recusa, silêncio ou prazo | CURRENT |
| Revisão humana posterior | Auditoria com resultado corrigido | CURRENT |

### 4.3 Exemplos de workflows possíveis (FUTURE)

O mesmo motor poderá atender: suporte N1, triagem inicial, qualificação de leads, atendimento comercial, cobrança, confirmação de dados, validação cadastral, validação de fornecedores, agendamentos, confirmação de consultas, entregas e pedidos, pesquisas, atendimento operacional, processos internos, outbound, inbound, reativação de clientes e acompanhamento de solicitações.

Validação cadastral e validação de fornecedores **existem hoje**. Os demais são exemplos de flexibilidade e **não estão implementados**. Nenhum deve ser apresentado como o propósito único do sistema.

## 5. IA conversacional

- **Hoje**: voz em tempo real com OpenAI Realtime, transcrição, TTS para falas exatas, intérprete local Qwen para respostas ambíguas, regras determinísticas e classificação estruturada. Detalhes em `TECHNOLOGY_ECOSYSTEM.md`.
- **Visão**: camada de provedores de IA que permita trocar ou combinar modelos (OpenAI, modelos open-weight e self-hosted como Qwen, outros), escolhidos por custo, privacidade, latência ou exigência do cliente.

## 6. Execução de ações e integração com sistemas

- **Hoje**: a integração acontece **antes e depois** da conversa. Sistemas externos (um ERP, por exemplo) enviam lotes e leem resultados e evidências pela API com Bearer token. BI lê indicadores pela API de Analytics. Não há chamada a sistemas externos **durante** a conversa, exceto a consulta de CNPJ feita antes de ligar.
- **Visão (central)**: a IA não só fala, ela age. Durante a conversa, o workflow chama tools: consultar cadastro, pedido ou cliente, verificar disponibilidade, criar ticket ou agendamento, atualizar status, registrar ocorrência, disparar webhook. A conversa segue com o resultado.

```text
Conversa → IA entende → Workflow → Tool/API → Sistema externo → Resultado → IA continua
```

## 7. Simulações e confiabilidade

A infraestrutura de simulação já existe (seção 3.5). A direção estratégica é transformá-la em **porta de entrada para produção**:

```text
Workflow → Simulação → Cenários → Métricas → Falhas → Correções → Aprovação → Produção
```

| Parte | Situação |
| --- | --- |
| Simulação IA × IA, cenários com gabarito, métricas, avaliação, baterias | CURRENT (para `supplier_validation`) |
| Cenários de usuário cooperativo, resposta parcial ou difícil | CURRENT (favorável, parcial, difícil) |
| Silêncio, interrupção (barge-in), resposta composta | tratados pelo agente; parte dos cenários atuais |
| Usuário confuso, informações contraditórias, mudança de assunto, intenção inesperada | parcialmente representados nos cenários difíceis; catálogo amplo é FUTURE |
| Falha de API ou de integração como cenário | FUTURE (não há tools para falhar) |
| Simulação de workflows criados pelo usuário | PLANNED |
| Aprovação formal antes de publicar em produção | FUTURE |

**Não afirmar que a camada de confiabilidade está completa.** Afirmar: "o LeadPulse já simula e avalia o agente antes de ligar para pessoas reais". Isso é verdade para o workflow existente.

## 8. Princípios do produto

1. **O workflow controla, a IA conversa.** Regras e etapas explícitas, com IA para linguagem natural.
2. **Toda conclusão tem evidência.** Resultado ligado à pergunta, à resposta e à gravação, quando houver.
3. **Testar antes de ligar.** Simulação e avaliação fazem parte do ciclo.
4. **Humano no controle.** Revisão e correção de resultados; transferência para humano é visão.
5. **Transparência com quem atende.** A chamada se identifica como automatizada e a recusa é respeitada.
6. **Dados sob regras da empresa.** LGPD, retenção, anonimização, credenciais cifradas por conta.
7. **Sem dependência de um único fornecedor.** Hoje a empresa usa as próprias contas Twilio e OpenAI; a visão é de camadas intercambiáveis.
8. **Honestidade sobre o que existe.** O que é visão aparece como visão.

## 9. CURRENT vs FUTURE — resumo

| Tema | CURRENT | FUTURE / PLANNED |
| --- | --- | --- |
| Workflows | 3 fluxos predefinidos em código | Custom Workflows criados pela empresa |
| Canal | Ligação de saída (Twilio) | Inbound; WhatsApp como canal de fallback |
| IA | OpenAI Realtime, transcrição, TTS, Responses API; Qwen local como intérprete auxiliar | Camada de provedores; modelos self-hosted como modelo principal |
| Ações | Classificar e registrar resultado; fallback por e-mail | Tools e APIs durante a conversa; webhooks |
| Integração | API REST para lotes, resultados e evidências; API de BI | Conectores de CRM, ERP, TMS, agenda e tickets |
| Transferência | — | Transferência para humano |
| Simulação | IA × IA, 15 cenários, avaliação, baterias, áudio ao vivo | Microfone no navegador, ligação de teste, qualquer workflow, aprovação para produção |
| Observabilidade | Status, eventos, transcrição, Analytics, auditoria, métricas operacionais | Observabilidade por workflow e por etapa |
| Provedores | Twilio, OpenAI, Ollama/Qwen, SMTP, Meta Cloud API (parcial) | Camadas intercambiáveis de IA, telefonia e mensageria |
| Complementos | App Flutter de acompanhamento (protótipo) | — |
