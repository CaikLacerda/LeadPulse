# LeadPulse — Fase 0 — 17/10/2026

## Resumo executivo

As correções locais foram implementadas no Rails, reaproveitando seletivamente a auditoria e preservando o WIP. Foram integrados evidências, anonimização, backfill com preview, idempotência, isolamento da sincronização, Request ID, TLS/CSP, rate limits, guardas C1, métricas e verificações de CI. A FastAPI original e os experimentos permaneceram intactos.

**A Fase 0 ainda não autoriza avançar para a Fase 1 comercial.** C1 depende de confirmação/rotação operacional; vulnerabilidades confirmadas no runtime congelado da FastAPI exigem evolução coordenada. Nenhuma operação em produção, deploy, rotação real, commit, push ou backfill de escrita foi executada.

## Preservação e divergência

- Rails: `feat/simulacoes`, HEAD `3221add9d8fb435f018d744409325e90853cb69f`.
- Serviço Python: `feat/simulacoes`, commit `e43e0f71769036e4542f4c5a167ac63d0e280fcf`.
- Divergência confirmada: 13 commits próprios de simulações e 16 de auditoria.
- Backups duráveis: `/home/calves/leadpulse-phase0-backups/20261017`, acesso 0700, conteúdo sensível. Incluem bundles verificados, patches staged/unstaged separados, bytes da index, status e lista de untracked, arquivos completos e manifestos SHA-256. Arquivos SQLite receberam cópias consistentes com `sqlite3.Connection.backup` e `integrity_check`.
- Evidências de execução e comparação: `/tmp/leadpulse-phase0-backup-20261017`. Nenhum arquivo anterior foi perdido. Os 130 caminhos do WIP Rails foram inventariados; nos seis arquivos compartilhados com esta implementação, remover apenas os acréscimos desta execução reproduz exatamente o conteúdo anterior. A prova está em `wip-hunk-preservation.json`. HEAD, branch, bytes da index e patch staged foram comparados com o backup. As cinco exclusões staged foram preservadas.
- Fingerprint B3: `046269a4272bae2698283a939b389ebb955562e9135bd56560a797bdd169c796`; os 125 arquivos Python conferem antes e depois. Os 393 arquivos existentes nos quatro diretórios experimentais protegidos conferem por SHA-256. Nenhum banco experimental foi aberto por testes ou reprocessado.
- WIP frontend, landing, autenticação, assets, migrations e schema preservados. Na API mobile, apenas foi acrescentado o callback de Request ID e seu teste; o conteúdo anterior permanece. Em arquivos compartilhados, a integração preservou os hunks anteriores em vez de substituir os arquivos pela versão da auditoria.

## Integração seletiva

Foram reaproveitados `0436494`, `38a4107`, `c42d6be`, `1812414`, `0279b1b`, `4b5ed86`, `45e99de`, `1601358`, `f56f557`, `106519f`, `6b07cd4`, `2ec6ddf`, `89b82a8`, `2c3f05e` e `a9c1723`. O ajuste do botão em `5af27de` já existia e não foi reaplicado.

Dependências respeitadas: cliente de evidências → merger → sync/anonimização → backfill; Request ID → contexto de requisição/job; idempotência → teste ajustado de token da auditoria; segurança → controllers e rotas Devise. O teste de tenancy foi integrado preservando a exceção pessoal `mobile_sessions` do WIP. Brakeman passou a 8.1.0 e a análise usa a versão fixada, sem consulta de versão durante o scan offline.

O [inventário por arquivo](arquivos-modificados.md) registra motivo e referência de cada mudança em relação ao backup inicial, não em relação ao HEAD já sujo.

| Correção | Status | Validação | Observações |
|---|---|---|---|
| Evidências | Implementada | Contrato com fixtures exportadas pela FastAPI; erros, repetição, paginação, IDs e tenants | União por external_id dentro do lote; tentativas por attempt_number; preserva tentativas anteriores |
| Anonimização | Implementada | Testes de scrub, metadados e concorrência | Recarrega sob lock; sync não restaura gravações/transcrições; preserva contagem/duração/status |
| Idempotência | Integrada | Duplo início em voo, timeout/retry, claim expirado | Claim persistido sob lock; reutiliza batch_id quando confirmação remota é incerta |
| Sync isolado | Integrado | Falha de um lote/empresa não interrompe os demais | Lotes cadastrais e retornos comerciais; erro reportado com contexto |
| Request ID | Integrado | Cliente HTTP e mobile | Requisições web/mobile e jobs propagam X-Request-ID |
| TLS/CSP | Implementada | Segurança/CSP e origem WebSocket | Report-only; wss em produção; prefixo de reverse proxy preservado no áudio |
| Rate limits | Integrados | Login, recuperação, janela, IP/identidade | Contadores compartilhados em produção; indisponibilidade retorna 503 |
| CI/Brakeman | Verificações locais aprovadas | Lint, testes, análise estática e advisories | GitHub Actions não foi disparado; index original ainda falha corretamente no scanner |
| Proteções C1 | Código implementado; incidente aberto | Guarda por fingerprint e dry-run de recifragem de tokens | Boot de produção bloqueia material comprometido; rotação real pendente |
| Autorizações | Rails corrigido; FastAPI pendente | Negativos de viewer e tenant | Criação mantém redirect de recusa existente; cancel/ticket negam com 403 |

## Contrato Rails ↔ FastAPI e limites

A cópia descartável da FastAPI executou `scripts/export_contract_fixtures.py` com SQLite temporário, bloqueio de rede e substitutos locais dos providers. Gerou respostas reais de `GET /validations/{id}` e `GET /validations/{id}/evidence`. Os testes Rails consumiram essas respostas usando `VALIDATION_API_CONTRACT_FIXTURES_DIR=/tmp/leadpulse-phase0-contract`.

O merger preserva respostas legadas, mescla privacidade e timestamps UTC, rejeita lote divergente e outro tenant, não descarta evidências em falha de busca e não duplica tentativas. Anonimização tem precedência sobre evidência antiga ou recebida durante uma corrida. O início identifica o payload anterior pelo lote sem apagar sua cópia antes da confirmação; respostas atrasadas de criação não regridem status concluído nem restauram evidências anonimizadas. A anonimização rejeita resposta de um lote que tenha sido substituído enquanto a chamada remota estava em andamento.

O teto anterior de dez páginas foi removido. Há limite defensivo de 1.000 páginas de 200 registros (até 200.000 registros); se `has_more` não terminar, a coleta é rejeitada, o snapshot anterior é mantido e não se marca sincronização completa. Há teste de paginação além de 2.000 registros e de endpoint que nunca encerra. Lotes acima desse limite exigem paginação retomável numa etapa posterior; não são silenciosamente truncados.

Lotes concluídos/com erro e `finished_at` nas últimas 24 horas são revisitados no máximo a cada 15 minutos para capturar evidências tardias. Depois dessa janela, ou sem `finished_at`, exigem sincronização manual dirigida; isso evita polling indefinido de todo o histórico. O comportamento de parada tem teste. Nenhuma rotina nova reprocessa os resultados experimentais.

## Preview e plano de backfill

Consulta SQL local executada com `default_transaction_read_only=on`: **12 lotes, 13 registros, 13 tentativas declaradas** têm o formato separado ainda sem evidências. São candidatos, não uma afirmação de que 13 gravações existem na API. Nenhum token ou dado pessoal foi impresso.

Não foi feita busca remota contra lotes históricos: o preview exato da API está implementado e testado com fakes, mas a contagem exata de alterações depende dessa consulta coordenada. Nenhuma escrita de backfill foi executada em banco real.

1. Operador escolhe a conta e preserva um backup consistente do estado imediatamente anterior.
2. Listagem local: `ACCOUNT_ID=<id> bin/rails evidence:backfill` (sem PREVIEW/APPLY, apenas candidatos).
3. Preview remoto coordenado: `ACCOUNT_ID=<id> PREVIEW=1 bin/rails evidence:backfill`; revisar quantidades/falhas sem gravar lotes Rails. Confirmar previamente que o ambiente remoto consultado é o correto.
4. Só após autorização específica: `ACCOUNT_ID=<id> APPLY=1 bin/rails evidence:backfill`. O código revalida payload e batch_id sob lock; alteração concorrente ou anonimização aborta aquela aplicação.
5. Conferir Analytics, Auditoria e LGPD; repetir o preview para detectar pendências. Recuperação é por snapshot dos lotes afetados, sem restaurar o banco inteiro sobre gravações concorrentes.

## Testes e comandos

As execuções Rails usaram `RAILS_ENV=test DATABASE_URL=postgresql://phase0@127.0.0.1:55439/leadpulse_phase0_test PARALLEL_WORKERS=1`, com PostgreSQL exclusivo em `/tmp/leadpulse-phase0-postgres`. Migrations foram executadas somente nesse banco. O servidor PostgreSQL descartável foi encerrado após os testes. `bin/offline` bloqueia acesso externo; fixtures/stubs substituem providers.

| Comando executado | Resultado final | Limites e evidências |
|---|---|---|
| `bin/offline bin/rails test` | **394 testes, 2.568 assertions; 0 falhas, 0 erros, 0 skips** | `full-tests-final.log`; inclui tenancy, autenticação, mobile, simulação, sync e anonimização |
| `VALIDATION_API_CONTRACT_FIXTURES_DIR=/tmp/leadpulse-phase0-contract bin/offline bin/rails test test/services/supplier_imports/remote_evidence_merger_test.rb` | **17 testes, 47 assertions; 0 falhas/erros/skips** | `live-contract-tests.log`; subset também presente na suíte completa, repetido com fixtures recém-exportadas |
| `bin/offline bin/rails test:system` | **4 testes, 16 assertions; 0 falhas/erros/skips** | `system-tests.log`; RackTest, sem chamadas de áudio reais |
| `bin/offline bin/rails test test/services/supplier_imports/start_sync_races_test.rb test/services/supplier_imports/remote_evidence_merger_test.rb` | **20 testes, 62 assertions; 0 falhas/erros/skips** | `races-green.log`; confirmação focada antes da suíte final |
| `PYTHONDONTWRITEBYTECODE=1 POSTGRES_TEST_DATABASE_URL=postgresql://phase0@127.0.0.1:55439/leadpulse_phase0_fastapi_test timeout 900 /home/calves/api_confaith_ai/.venv/bin/python -u -m pytest -q -o faulthandler_timeout=60` | **1.320 testes aprovados; 0 falhas, 0 skips; 1 warning** | `fastapi-tests-final-with-git.log`; executado em `/tmp/leadpulse-phase0-fastapi`, incluindo os seis testes PostgreSQL em schema descartável |
| `node --test test/javascript/*.mjs` | **1 aprovado; 0 falhas/skips** | `javascript-tests.log`; controle de áudio com fakes |
| `RUBOCOP_CACHE_ROOT=/tmp/leadpulse-phase0-rubocop bin/rubocop --format simple` | **305 arquivos, 0 infrações** | `rubocop.log` |
| `bin/brakeman --no-pager -f json -o /tmp/leadpulse-phase0-backup-20261017/brakeman.json` | **0 alertas ativos, 0 erros** | Uma exceção específica justificada em `config/brakeman.ignore` e no runbook |
| `BUNDLER_AUDIT_DB=/tmp/leadpulse-phase0-advisory-db bin/bundler-audit check --update` | **Nenhuma vulnerabilidade encontrada** | Base pública com 1.266 advisories; commit `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485` |
| `bin/importmap audit` | **Nenhum pacote vulnerável encontrado** | ECharts e GL incluídos por versão; nenhum desses dois pacotes foi ignorado no resultado final |
| `gitleaks dir /tmp/leadpulse-phase0-candidate-scan --redact=100 ...` | **0 segredos encontrados no código proposto** | Snapshot dos arquivos tracked atuais e arquivos novos desta execução; relatório redigido |
| `GITLEAKS_BIN=/tmp/leadpulse-phase0-backup-20261017/gitleaks python3 scripts/scan_secrets.py` | **1 detecção esperada na index original: segredo fixo Devise** | `secrets-scan.log`; falha real mantida até o operador stagear a correção. Não houve exceção para esse segredo |
| `git diff --check` | **Aprovado** | Sem erros de whitespace |

O warning Python é a depreciação do alias `HTTP_422_UNPROCESSABLE_ENTITY`, em teste de onboarding; nenhuma mudança no código congelado foi feita para silenciá-lo. Os seis testes PostgreSQL inicialmente pulados passaram ao configurar o banco descartável exclusivo. A única falha da primeira suíte completa Python era ausência de `.git` na cópia; foi reproduzida e corrigida restaurando metadados do bundle, sem alterar Python. Os seis testes do módulo de fingerprint passaram isoladamente e a execução completa posterior aprovou todos os 1.320 casos.

A revisão de qualidade identificou e corrigiu as corridas adicionais de substituição de lote, criação atrasada e anonimização. Uma mutação temporária da guarda de resposta atrasada fez o teste falhar com status `processando` no lugar de `concluido`; o arquivo foi restaurado por cópia antes da suíte final aprovada. `stale-response-mutation.log` registra a prova de sensibilidade do teste, não uma falha pendente. Nenhum commit ou merge foi feito para essa revisão.

A primeira integração passou com 375 testes. Uma rodada intermediária detectou regressão de redirect versus 403 no create de simulações; o comportamento anterior foi restaurado e a suíte voltou a passar. O primeiro Brakeman encontrou falha no mecanismo de consulta de versão, corrigido pela execução da versão fixada; não foi suprimido alerta para resolver isso. O primeiro teste FastAPI travou no AnyIO dentro do sandbox; a suíte foi reiniciada na mesma cópia descartável com a restrição de processo removida e o bloqueio de providers mantido. Nenhum teste usou banco compartilhado ou experimental.

Os logs e manifestos finais também foram preservados em `/home/calves/leadpulse-phase0-backups/20261017/verification`, com manifesto SHA-256 próprio e acesso restrito.

## Segurança e próximos passos

C1 tem guardas, scanner, hook preparado, dry-run transacional de tokens e [procedimento operacional](../security.md). A chave local ainda corresponde ao fingerprint comprometido; a exposição histórica não foi reescrita. Uso/rotação em produção continuam sem confirmação. Nenhuma chave real foi gerada/substituída.

Os seis [cards da FastAPI congelada](pendencias-fastapi.md) registram evidência, migração e aceite para permissões, eventos por token de cliente, fallback global OpenAI, estilo, secrets legados e SMTP SSRF. Não é seguro declarar esses riscos resolvidos apenas com mudanças no Rails.

A index original inclui a chave Devise removida apenas do working tree; o scanner staged retorna falha real. O snapshot do código proposto passa. O operador deverá revisar e stagear a remoção quando autorizar commits; instalar o hook local e exigir os checks no remoto. Nada disso foi feito nesta execução.

**Próximo passo:** executar a janela C1 aprovada, revisar a integração local para commit e aprovar a linha de manutenção fora do snapshot B3. Após resolver os riscos remotos, aplicar o backfill aprovado e confirmar CI/ambientes reais. Só então reavaliar a entrada na Fase 1 (`Conversation + ConversationEvent + UsageEvent`). A Fase 1 não foi iniciada.
