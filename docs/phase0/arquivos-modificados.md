# Arquivos alterados nesta execução

Comparação com o snapshot inicial, incluindo arquivos novos. Arquivos WIP que já diferiam do HEAD e não foram alterados nesta execução não entram nesta tabela.

| Arquivo | Motivo e problema resolvido | Referência |
|---|---|---|
| `.githooks/pre-commit` | Executar guardas de caminhos e scanner antes de futuros commits; hook não instalado automaticamente. | 2ec6ddf |
| `.github/workflows/ci.yml` | Executar testes offline com banco de teste nomeado explicitamente. | 2c3f05e |
| `.github/workflows/secrets.yml` | Adicionar scanner staged no CI com executável fixado e checksum verificado. | 2ec6ddf |
| `.gitignore` | Ignorar arquivos de chave e diretório local de segredos. | 2ec6ddf |
| `Gemfile.lock` | Reaproveitar atualização auditada de Brakeman 8.0.6 para 8.1.0 com checksum. | f56f557 |
| `app/controllers/api/v1/mobile/base_controller.rb` | Acrescentar somente o contexto de Request ID ao WIP mobile existente. | 45e99de |
| `app/controllers/application_controller.rb` | Acrescentar contexto de Request ID preservando o layout e demais alterações WIP. | 45e99de |
| `app/controllers/concerns/authentication_throttle.rb` | Limitar tentativas de login e recuperação por IP e identidade+IP com falha fechada. | 89b82a8 |
| `app/controllers/csp_reports_controller.rb` | Receber relatórios CSP com corpo/logs limitados e sem URLs ou tickets sensíveis. | 89b82a8 |
| `app/controllers/simulations_controller.rb` | Negar cancelamento/tickets a leitores e montar URL de áudio validada, preservando prefixos de proxy e recusa existente de create. | Fase 0 — autorizações; 89b82a8 |
| `app/controllers/users/passwords_controller.rb` | Aplicar limites de recuperação de senha ao controller Devise. | 89b82a8 |
| `app/controllers/users/sessions_controller.rb` | Aplicar limites de login ao controller Devise. | 89b82a8 |
| `app/jobs/application_job.rb` | Propagar identificador do job às chamadas HTTP sem deixar contexto vazar para outro job. | 45e99de |
| `app/models/account.rb` | Permitir chave explícita na derivação do cifrador para ensaiar a rotação sem trocar segredos reais. | 2ec6ddf |
| `app/models/current.rb` | Manter Request ID isolado por requisição/job. | 45e99de |
| `app/models/supplier_import.rb` | Ler validade de evidências em UTC e evitar parsing incorreto no fuso local. | c42d6be |
| `app/services/commercial_opportunities/sync_all_remote_statuses_service.rb` | Isolar falhas inesperadas em retornos comerciais para continuar os demais tenants. | 0436494 |
| `app/services/maintenance/reencrypt_validation_tokens.rb` | Ensaiar recifragem de tokens por padrão sem escrita; aplicar transacionalmente somente quando solicitado pelo operador. | 2ec6ddf |
| `app/services/maintenance/remote_evidence_backfill.rb` | Listar candidatos, comparar evidências em preview e revalidar concorrência antes de eventual escrita autorizada. | 0279b1b; 4b5ed86 |
| `app/services/supplier_imports/anonymize_evidence_service.rb` | Preservar metadados de chamadas, remover evidências pessoais e revalidar o lote sob lock após a chamada remota. | 1812414 |
| `app/services/supplier_imports/audit_entries_service.rb` | Evitar leitura/processamento da planilha quando somente resultados são necessários. | 1601358 |
| `app/services/supplier_imports/privacy_refusal_registry.rb` | Consultar resultados de recusas sem carregar planilhas desnecessariamente. | 1601358 |
| `app/services/supplier_imports/remote_evidence_merger.rb` | Unir resultados/evidências por IDs estáveis, preservar tentativas, paginar e tratar falhas/anonimização/gravações tardias. | 1812414 |
| `app/services/supplier_imports/start_remote_validation_service.rb` | Reivindicar início sob lock e reutilizar batch_id em retries de resultado incerto. | 38a4107 |
| `app/services/supplier_imports/sync_all_remote_statuses_service.rb` | Isolar falhas por lote e revisitar lotes recentes com frequência e janela limitadas. | 0436494 |
| `app/services/supplier_imports/sync_remote_status_service.rb` | Buscar evidências separadas, validar o lote e preservar privacidade/estado concorrente sob lock. | 1812414 |
| `app/services/tenancy/integrity_check.rb` | Cotar identificadores SQL de tabelas na verificação de integridade. | f56f557 |
| `app/services/validation_api/base_client.rb` | Acrescentar X-Request-ID às chamadas HTTP para correlação ponta a ponta. | 45e99de |
| `app/services/validation_api/validations/show_evidence_service.rb` | Consumir GET /validations/{id}/evidence com paginação e escape de path. | 1812414 |
| `bin/brakeman` | Usar a versão fixada no lockfile; retirar consulta de versão durante análise offline. | f56f557 |
| `bin/offline` | Executar scripts Rails com bloqueio de rede externa para providers. | 2c3f05e |
| `bin/security_check` | Rejeitar caminhos de segredo na index e chaves comprometidas no preflight de deploy. | 2ec6ddf |
| `config/brakeman.ignore` | Documentar um único falso positivo específico de role autorizado e validado no convite de equipe. | f56f557 |
| `config/environments/production.rb` | Exigir HTTPS, cookies seguros e HSTS inicial; assumir TLS do proxy só por opção explícita. | 89b82a8 |
| `config/environments/test.rb` | Usar cache em memória para validar limites offline de autenticação. | 89b82a8 |
| `config/importmap.rb` | Informar ao auditor as versões já documentadas de ECharts/GL; eliminar dependências ignoradas. | Fase 0 — CI |
| `config/initializers/compromised_credentials.rb` | Bloquear boot de produção com master key ou secret_key_base comprometidos. | 2ec6ddf |
| `config/initializers/content_security_policy.rb` | Habilitar CSP report-only com nonce e origem WebSocket configurável. | 89b82a8 |
| `config/initializers/devise.rb` | Remover chave Devise fixa do working tree; index e histórico permanecem preservados. | 2ec6ddf |
| `config/initializers/operational_metrics.rb` | Emitir métricas operacionais EMF com dimensões limitadas, sem dados de tenant/pessoa. | a9c1723 |
| `config/routes.rb` | Integrar controllers de sessão/senha e endpoint CSP preservando todas as rotas WIP, inclusive mobile/simulações. | 89b82a8 |
| `docs/arquitetura_multi_tenant.md` | Registrar regras de integração e responsabilidades entre Rails e API. | 6b07cd4 |
| `docs/phase0/arquivos-modificados.md` | Mapear cada mudança desta execução ao motivo e referência. | Fase 0 — entrega |
| `docs/phase0/pendencias-fastapi.md` | Registrar seis riscos confirmados que exigem evolução coordenada fora do snapshot B3. | Fase 0 — diagnóstico no código |
| `docs/phase0/relatorio.md` | Registrar resultado, evidências, testes, preview, limitações e critérios para avançar. | Fase 0 — entrega |
| `docs/security.md` | Entregar runbook C1, dry-run, rotação pendente, guardas e configuração TLS/CSP. | 2ec6ddf; 89b82a8 |
| `lib/security/compromised_key_guard.rb` | Detectar material comprometido usando somente fingerprints públicos, sem imprimir segredos. | 2ec6ddf |
| `lib/security/validation_websocket_origin.rb` | Validar configuração de origem de áudio e derivar connect-src sem credenciais/query/wildcard. | 89b82a8 |
| `lib/tasks/evidence.rake` | Oferecer listagem/preview/apply explícitos e contagens para backfill por conta. | 0279b1b; 4b5ed86 |
| `lib/testing/network_guard.rb` | Bloquear tráfego externo nos testes, inclusive conexões libcurl e sockets. | 2c3f05e |
| `scripts/scan_secrets.py` | Inspecionar bytes staged, exigir Gitleaks e publicar somente caminho/linha/regra. | 2ec6ddf |
| `test/architecture/compromised_key_guard_test.rb` | Rejeitar a chave histórica comprometida sem revelar material e verificar ausência de caminhos de segredo na index. | 2ec6ddf |
| `test/architecture/provider_network_guard_test.rb` | Comprovar bloqueio de tráfego externo em testes. | 2c3f05e |
| `test/architecture/tenancy_schema_test.rb` | Exigir account_id em novas tabelas fora das exceções explícitas; preservar mobile_sessions como tabela pessoal. | 106519f |
| `test/architecture/validation_websocket_origin_test.rb` | Testar origem segura, report-only e preservação do prefixo de reverse proxy. | 89b82a8 |
| `test/controllers/api/v1/mobile_api_test.rb` | Acrescentar teste de Request ID, preservando os testes mobile anteriores. | 45e99de |
| `test/controllers/simulations_controller_test.rb` | Acrescentar testes negativos de permissão e preservar os cenários de simulação do WIP. | Fase 0 — autorizações |
| `test/fixtures/files/validation_api/validation_batch_evidence.json` | Preservar exemplo exportado pela API para testar o contrato separado de resultado/evidências. | 1812414 |
| `test/fixtures/files/validation_api/validation_batch_result.json` | Preservar exemplo exportado pela API para testar o contrato separado de resultado/evidências. | 1812414 |
| `test/integration/security_controls_test.rb` | Validar limites de login/recuperação, expiração das janelas e relatórios CSP limitados. | 89b82a8 |
| `test/models/supplier_import_test.rb` | Validar timestamps de expiração em UTC, inclusive entradas inválidas. | c42d6be |
| `test/services/commercial_opportunities/sync_all_remote_statuses_service_test.rb` | Comprovar que uma falha comercial não interrompe sincronização de outro tenant. | 0436494 |
| `test/services/maintenance/remote_evidence_backfill_test.rb` | Comprovar contagens de preview, ausência de escrita no preview e aplicação isolada de evidências. | 0279b1b; 4b5ed86 |
| `test/services/reencrypt_validation_tokens_test.rb` | Validar dry-run de recifragem, idempotência e rollback de tokens ilegíveis. | 2ec6ddf |
| `test/services/supplier_imports/remote_evidence_merger_test.rb` | Cobrir os dois endpoints, tentativas, paginação, falhas, lote/tenant divergente, gravações tardias e anonimização concorrente. | 1812414 — extensão Fase 0 |
| `test/services/supplier_imports/start_remote_validation_service_test.rb` | Preservar normalização existente e validar duplo clique, timeout/retry com mesmo batch_id e claim expirado. | 38a4107; 2ec6ddf |
| `test/services/supplier_imports/start_sync_races_test.rb` | Reproduzir mistura de lotes, resposta de criação atrasada e anonimização concorrente; validar as guardas correspondentes. | 38a4107; 1812414 — extensão Fase 0 |
| `test/services/supplier_imports/sync_all_remote_statuses_service_test.rb` | Validar isolamento de falhas e janela/frequência limitadas de consultas após a conclusão. | 0436494 — extensão Fase 0 |
| `test/services/validation_api/base_client_test.rb` | Validar propagação de X-Request-ID e chamadas sem contexto de requisição. | 45e99de |
| `test/support/provider_network_guard.rb` | Instalar o bloqueio de providers no runner de testes. | 2c3f05e |
| `test/test_helper.rb` | Instalar bloqueio externo antes do boot e limpar cache para testar rate limits isoladamente. | 2c3f05e; 89b82a8 |

Total: 71 arquivos. Nenhum arquivo de aplicação da FastAPI foi modificado.
