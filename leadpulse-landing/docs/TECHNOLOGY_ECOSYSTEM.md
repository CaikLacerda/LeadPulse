# Ecossistema tecnológico — LeadPulse

Todo item marcado como **CURRENT** foi conferido no código em 15/10/2026, nos repositórios `LeadPulse` (Rails) e `api_confaith_ai` (FastAPI). A legenda está em `BRIEF.md`.

Duas classificações diferem da expectativa inicial do briefing:

- **Twilio** é **CURRENT**, não "avaliado". É a telefonia de produção.
- **Qwen** é **CURRENT** num papel **auxiliar e restrito**: o `qwen3:1.7b`, self-hosted via Ollama, interpreta respostas ambíguas. Como modelo conversacional principal, continua **FUTURE**.

E uma ficou abaixo da expectativa:

- **Meta WhatsApp Cloud API** é **PARTIAL**: envio e webhook existem, mas só no fluxo de teste local. O fallback de produção hoje é por **e-mail**.

---

## 1. Arquitetura atual

```text
Navegador ──► Rails (LeadPulse) ──HTTP + Bearer──► FastAPI (api_confaith_ai)
               telas, contas,                       credenciais de provedores (cifradas por empresa)
               lotes, Analytics,                    lotes ──► outbox ──► Amazon SQS ──► worker
               LGPD, simulações                      worker ──► Twilio REST (liga com a conta da empresa)
               ▲                                    Twilio ◄─WebSocket─► FastAPI ◄─WebSocket─► OpenAI Realtime
               │ polling (resultado,                   status da chamada ──► outbox ──► SQS ──► worker
               │ evidências, eventos)                 Ollama/Qwen local: respostas ambíguas
               └───────────────────────────────────── BrasilAPI (CNPJ) · OpenAI web search (busca)
                                                    SMTP: fallback por e-mail
Navegador ◄──WebSocket (ticket)── FastAPI: monitor de áudio da simulação (só escuta)
ERP / sistemas externos ──HTTP + Bearer──► FastAPI (enviar lotes, ler resultado e evidências)
BI ──HTTP + token de BI──► Rails /api/v1/analytics/*
```

Fontes: `api_confaith_ai/docs/architecture.md`, `realtime.md`, `queues.md`, `simulations.md`.

- Não há webhook de saída da FastAPI para o Rails nem para sistemas de clientes. Quem consome faz polling.
- A fonte da verdade de execução e evidências é a FastAPI. O Rails guarda uma cópia para Analytics, auditoria, exportação e LGPD.

## 2. Stack atual

### Aplicação web (Rails)

| Tecnologia | Uso | Evidência |
| --- | --- | --- |
| Ruby on Rails 8.1 | aplicação principal | `Gemfile` |
| Hotwire (Turbo, Stimulus), importmap | interface | `Gemfile`, `app/javascript/controllers/` |
| Tailwind CSS 4, Propshaft | estilos e assets | `Gemfile`, `app/assets/tailwind/` |
| PostgreSQL | banco | `config/database.yml` (`adapter: postgresql`), `compose.local.yml` |
| Devise | autenticação | `Gemfile` |
| Solid Queue, Solid Cache, Solid Cable | jobs, cache, cable | `Gemfile`; Solid Queue em produção, `async` em desenvolvimento |
| PaperTrail | histórico de alterações | `Gemfile` |
| roo, caxlsx | importação e exportação de planilhas | `Gemfile` |
| Typhoeus | cliente HTTP da API | `Gemfile` |
| ECharts | gráficos de Analytics | `vendor/` |
| Leaflet + OpenStreetMap | mapa de fornecedores | `vendor/`, `README.md` |
| Kamal, Docker, Thruster | deploy do Rails | `config/deploy.yml`, `Dockerfile` |

### Serviço de voz e IA (FastAPI)

| Tecnologia | Uso | Evidência |
| --- | --- | --- |
| FastAPI 0.119, Uvicorn, Pydantic 2 | API e webhooks | `requirements.txt` |
| SQLAlchemy 2, Alembic | persistência e migrations | `requirements.txt`, `migrations/` |
| PostgreSQL (psycopg) | banco de produção (SQLite só no ambiente local) | `requirements.txt`, `app/core/config.py` |
| websockets | Media Streams da Twilio, OpenAI Realtime, monitor de áudio | `requirements.txt`, `openai_realtime_bridge.py`, `simulation_audio_monitor.py` |
| Amazon SQS (boto3) | filas `voice-dispatch` e `call-events`, padrão outbox/inbox, DLQ | `docs/queues.md`, `scripts/sqs_worker.py` |
| AWS CodeBuild/CodeDeploy, CloudWatch | build, deploy, métricas EMF e alarmes | `buildspec.yml`, `appspec.yml`, `infra/`, `docs/observability.md` |
| systemd | API, worker, Ollama, reconciliação, retenção, backup | `systemd/` |
| cryptography | cifra das credenciais de provedores por empresa | `docs/security.md` |
| dateparser | interpretação de dia e horário falados | `requirements.txt`, `utils/callback_schedule.py` |

### Tempo real

- **CURRENT**: WebSocket entre Twilio, FastAPI e OpenAI Realtime durante a chamada; WebSocket do navegador para ouvir o áudio da simulação.
- **CURRENT**: o Rails acompanha lotes e simulações por **polling** (eventos com `after=<seq>`), não por WebSocket.

## 3. Camada de IA

### 3.1 OpenAI (CURRENT)

Cada empresa cadastra a própria chave OpenAI (`/configuracoes/openai`), guardada cifrada na FastAPI.

| Recurso | Uso no LeadPulse | Modelo padrão (configurável) | Status |
| --- | --- | --- | --- |
| Realtime API | agente de voz nas ligações e nas simulações; voz, velocidade, estilo e VAD por empresa | `gpt-realtime-2.1` | CURRENT |
| Transcrição no Realtime | transcrição das falas | `gpt-4o-transcribe` | CURRENT |
| Audio Speech (TTS) | falas determinísticas: texto exato dos turnos obrigatórios | `gpt-4o-mini-tts` | CURRENT |
| Responses API + tool `web_search` | busca de fornecedores por segmento e região | `gpt-4.1-mini` | CURRENT |
| Responses API + saída estruturada (`json_schema` estrito) | normalização de condições comerciais | configurável (`OPENAI_COMMERCIAL_NORMALIZATION_MODEL`) | CURRENT, OPTIONAL (pode ser desligada) |
| Segunda sessão Realtime como contraparte simulada | simulação IA × IA | mesmo da conta | CURRENT |
| GPT-Live (`gpt-live-1`) | protocolo experimental de simulação, por opt-in | `gpt-live-1` | PARTIAL (experimental, com limitações documentadas) |
| Function/tool calling do agente de voz | — | — | **não usado** (FUTURE) |
| LLM como avaliador | — | — | **não usado**: a avaliação é por regras |

Arquivos: `app/services/openai_realtime_bridge.py`, `deterministic_speech.py`, `supplier_discovery_service.py`, `commercial_terms_normalizer_service.py`, `openai_live_bridge.py`, `app/core/config.py`.

### 3.2 Qwen e modelos self-hosted

| Item | Status | Detalhe |
| --- | --- | --- |
| Qwen `qwen3:1.7b` via Ollama local | **CURRENT (auxiliar)** | Interpreta só respostas compostas ou ambíguas durante a ligação; contexto limitado a 1024 tokens; sem custo por chamada de API; roda na infraestrutura própria (`semantic_turn_interpreter_service.py`, `systemd/confaith-ollama.service`). A API só fica pronta (`/ready`) com o modelo carregado. |
| Limitação conhecida | — | Em CPU pode levar perto de 5 s. Sem ele, respostas compostas não são aceitas e o agente repete a pergunta (`docs/simulations.md`). |
| Qwen ou outro open-weight como modelo **principal** da conversa | **FUTURE / EVALUATED** | Não há implementação. |

Para a landing: o fato de o LeadPulse já rodar um modelo local para uma parte da interpretação **dá credibilidade** à visão de "IA sob controle da empresa". Mas não se pode dizer que a conversa roda self-hosted.

### 3.3 Visão: camada de provedores de IA (FUTURE)

```text
LeadPulse
   ↓
AI Provider Layer
   ├─ OpenAI
   ├─ Qwen (self-hosted)
   └─ outros modelos
```

Objetivo: trocar ou combinar provedores por custo, privacidade, latência ou exigência do cliente.

Hoje existe uma abstração parcial: o protocolo do agente (`voice_agent_protocol.py`, `realtime` x `gpt_live`) já é intercambiável, mas só dentro da OpenAI.

## 4. Camada de telefonia

### Twilio (CURRENT)

| Recurso | Uso | Evidência |
| --- | --- | --- |
| Credenciais e números por empresa | cada empresa usa a própria conta e os próprios números | Rails `/configuracoes/twilio`; `twilio_credential.py`, `twilio_phone_number.py` |
| REST API: ligações de saída | disparo pelo worker | `twilio_voice_service.py` |
| TwiML + Media Streams (WebSocket) | áudio bidirecional com o agente | `/webhooks/twilio/voice/twiml`, `/media-stream/{id}` |
| Status callbacks | status da chamada → fila de eventos | `/webhooks/twilio/voice/status` |
| Assinatura dos webhooks | validação com o token da empresa | `docs/security.md` |
| Gravação | OPTIONAL, com remoção da gravação | `twilio_voice_service.py` (`Record`, `delete_recording`) |
| Ligações de entrada (inbound) | — | **não implementado** (FUTURE) |
| Transferência de chamada | — | **não implementado** (FUTURE) |

### Visão: camada de telefonia (FUTURE)

```text
LeadPulse
   ↓
Telephony Provider Layer
   ├─ Twilio
   └─ outros provedores
```

Hoje a telefonia é acoplada à Twilio (TwiML, Media Streams, assinatura). A troca de provedor exigiria uma camada nova.

## 5. Mensageria e fallback

| Canal | Status | Detalhe |
| --- | --- | --- |
| E-mail (SMTP) | **CURRENT** | Ligação não atendida → e-mail de fallback, se houver e-mail no lote ou na base oficial (`validation_async_service.py`, `email_service.py`). |
| Meta WhatsApp Cloud API | **PARTIAL** | `whatsapp_service.py` envia mensagem pela Graph API (`graph.facebook.com`); `/webhooks/whatsapp/meta` valida a assinatura e recebe respostas. **Só é usado pelo fluxo de teste local** (`LocalTestFlowService`). O serviço de produção não chama WhatsApp. Os status de WhatsApp já existem no domínio. |
| WhatsApp como fallback configurável por workflow | **PLANNED** | Direção do produto. |

O WhatsApp está ligado à **Meta Cloud API**, não à Twilio.

```text
ligação falhou → regra do workflow → fallback → WhatsApp / e-mail / nova tentativa     (FUTURE)
ligação não atendida → e-mail                                                          (CURRENT)
```

```text
LeadPulse
   ↓
Messaging Provider Layer
   ├─ Meta WhatsApp Cloud API
   ├─ e-mail (SMTP)
   └─ outros provedores                                                                (FUTURE)
```

## 6. Dados e serviços externos

| Serviço | Uso | Status |
| --- | --- | --- |
| BrasilAPI (CNPJ) | consulta de dados oficiais da empresa e telefone alternativo | CURRENT |
| OpenStreetMap / Nominatim | geocodificação e mapa | CURRENT |
| OpenAI web search | descoberta de fornecedores | CURRENT |

## 7. Integrações e APIs

### Hoje (CURRENT)

| Superfície | Para quê | Autenticação |
| --- | --- | --- |
| API de validação (FastAPI): `POST /validations`, `/supplier-validations`, `/commercial-validations`; `GET …/{id}`, `GET …/{id}/evidence` | sistemas externos enviam lotes e leem resultados e evidências | Bearer `tkn_live_…` por empresa; idempotência por `batch_id` |
| API de simulações (FastAPI) `/simulations` | criar, acompanhar e cancelar simulações | Bearer por empresa |
| API de BI (Rails) `/api/v1/analytics/summary`, `records`, `calls`, `batches` | ferramentas de BI leem indicadores | tokens de BI por empresa |
| OpenAPI `/openapi.json` e manual de integração | documentação do contrato | — |
| Página para desenvolvedores `/for-devs` | documentação no app | — |
| App mobile Flutter (`APP-LEAD-PULSE`) + rotas `/mobile` | acompanhamento de resultados | PARTIAL (protótipo complementar) |

### Visão: tools e ações (FUTURE, central)

A IA não só fala, ela executa ações durante a conversa:

```text
Conversa → IA entende → Workflow → Tool/API → Sistema externo → Resultado → IA continua
```

Integrações possíveis: CRM, ERP, TMS, sistemas internos, banco de dados, agenda, suporte e tickets, pedidos, cobrança, logística, APIs externas.

Ações possíveis: consultar cadastro, pedido ou cliente; criar ticket; atualizar status; registrar ocorrência; criar agendamento; verificar disponibilidade; disparar webhook; consumir API; executar tool.

Nada disso existe hoje. Não há tool calling no agente de voz nem webhook de saída.

## 8. Princípio provider-agnostic (FUTURE)

Evitar acoplamento excessivo a fornecedores. Camadas conceituais:

| Camada | Hoje | Visão |
| --- | --- | --- |
| AI Provider | OpenAI (voz, transcrição, TTS, busca, estruturação) + Qwen/Ollama (intérprete auxiliar) | Modelos intercambiáveis e combináveis |
| Telephony Provider | Twilio | Twilio e outros |
| Messaging Provider | SMTP; Meta Cloud API (parcial) | Meta Cloud API, e-mail e outros |
| Storage Provider | PostgreSQL; gravações na Twilio, com remoção controlada | Armazenamento configurável |
| Integration Provider | API REST de entrada; API de BI | Conectores de sistemas |
| Tool Provider | — | Tools por workflow |

```text
                         ┌─ OpenAI
Conversation → AI Layer ├─ Qwen
                         └─ outros

                         ┌─ Twilio
Telephony Layer ─────────┤
                         └─ outros

                         ┌─ Meta WhatsApp Cloud API
Messaging Layer ─────────┤
                         └─ outros

Workflow
   ↓
Tools
   ↓
CRM / ERP / TMS / APIs / sistemas internos
```

Fato atual que sustenta a direção: **cada empresa usa as próprias contas de Twilio e OpenAI**. O LeadPulse orquestra; o cliente controla as contas e paga cada provedor diretamente.

**Esta arquitetura não foi implementada. Esta tarefa apenas a documenta.**

## 9. Tabela de status

| Tecnologia | Categoria | Status | Uso |
| --- | --- | --- | --- |
| OpenAI Realtime API | IA (voz em tempo real) | **CURRENT** | Agente de voz das ligações e simulações |
| OpenAI transcrição (`gpt-4o-transcribe`) | IA (fala → texto) | **CURRENT** | Transcrição das conversas |
| OpenAI TTS (`gpt-4o-mini-tts`) | IA (texto → fala) | **CURRENT** | Falas determinísticas |
| OpenAI Responses API + web search | IA (busca) | **CURRENT** | Descoberta de fornecedores |
| OpenAI Responses API + JSON schema | IA (estruturação) | **CURRENT / OPTIONAL** | Normalização de condições comerciais |
| OpenAI GPT-Live | IA (voz) | **PARTIAL / EVALUATED** | Protocolo experimental de simulação |
| Tool calling (qualquer provedor) | IA (ações) | **FUTURE** | Ações em sistemas durante a conversa |
| Qwen `qwen3:1.7b` | IA self-hosted | **CURRENT (auxiliar)** | Intérprete de respostas ambíguas |
| Qwen como modelo principal | IA self-hosted | **FUTURE / EVALUATED** | Alternativa self-hosted |
| Ollama | Runtime de modelos | **CURRENT** | Executa o Qwen localmente |
| Twilio Voice + Media Streams | Telefonia | **CURRENT** | Ligações de saída, áudio, status, gravação opcional |
| Twilio inbound / transferência | Telefonia | **FUTURE** | Chamadas recebidas e transferência para humano |
| Outros provedores de telefonia | Telefonia | **FUTURE** | Camada intercambiável |
| Meta WhatsApp Cloud API | Mensageria | **PARTIAL** | Envio e webhook no fluxo de teste local |
| WhatsApp como fallback em produção | Mensageria | **PLANNED** | Fallback por regra do workflow |
| SMTP | E-mail | **CURRENT** | Fallback quando a ligação não é atendida |
| Ruby on Rails 8.1 | Backend web | **CURRENT** | Aplicação principal |
| Hotwire, Tailwind CSS 4 | Frontend do app | **CURRENT** | Interface do workspace |
| FastAPI | Backend de voz e IA | **CURRENT** | Ligações, IA, filas, evidências, simulação |
| PostgreSQL | Banco de dados | **CURRENT** | Persistência (Rails e FastAPI em produção) |
| Amazon SQS | Filas | **CURRENT** | Eventos assíncronos com outbox/inbox |
| AWS (CodeBuild, CodeDeploy, CloudWatch) | Infraestrutura | **CURRENT** | Deploy e observabilidade da API |
| Kamal + Docker | Infraestrutura | **CURRENT** (configurado) | Deploy do Rails |
| WebSockets | Tempo real | **CURRENT** | Twilio ↔ API ↔ OpenAI; monitor de áudio |
| BrasilAPI | Dados públicos | **CURRENT** | Consulta de CNPJ |
| OpenStreetMap / Nominatim / Leaflet | Mapas | **CURRENT** | Localização de fornecedores |
| ECharts | Visualização | **CURRENT** | Gráficos de Analytics |
| Flutter | Mobile | **PARTIAL** | App complementar (protótipo) |
| Conectores CRM / ERP / TMS / agenda / tickets | Integrações | **FUTURE** | Ações e consultas durante a conversa |
| Webhooks de saída | Integrações | **FUTURE** | Notificar sistemas de clientes |

## 10. Integração vs parceria

Não há evidência de parceria comercial formal com nenhuma empresa.

**Nunca usar**: "Parceiro OpenAI", "Parceiro Twilio", "Parceiro Meta", "certificado por", "em parceria com", "powered by" em selo de marca.

**Preferir**: "integração com", "compatível com", "infraestrutura baseada em", "provedor suportado", "tecnologia utilizada", "use a sua conta de…".

Logos de terceiros só podem ser considerados se:

1. a integração existe de fato (status CURRENT nesta tabela);
2. as diretrizes de marca do dono permitem esse uso;
3. a composição não sugere parceria oficial.

Mesmo para itens CURRENT, a recomendação padrão é **nome em texto, sem logo**, até que as diretrizes de cada marca sejam verificadas. Itens PARTIAL, PLANNED, EVALUATED e FUTURE nunca devem aparecer como logo, e só aparecem em texto na seção de visão.
