# Arquitetura multi-tenant do LeadPulse

A empresa (`Account`) é o tenant do LeadPulse. Todo dado de negócio pertence a uma empresa; o usuário (`User`) é a pessoa que acessa e aparece só como autor das ações.

## Modelo

| Entidade | Papel | Chaves |
| --- | --- | --- |
| `Account` | Empresa (tenant). Guarda dados cadastrais, integrações (token da API de validação criptografado, Twilio, OpenAI) e política LGPD | `accounts.id` |
| `User` | Pessoa: nome, e-mail e senha (Devise). Não guarda papel nem credencial | `users.id` |
| `AccountMembership` | Vínculo pessoa ↔ empresa, com `role` e `status` (`active`/`disabled`) | único `(account_id, user_id)` |
| `AccountInvitation` | Convite pendente para entrar numa empresa | `token_digest` único; um convite aberto por e-mail e empresa |
| `AnalyticsApiToken` | Token somente leitura da API de Analytics (BI) | `token_digest` único |

Uma pessoa pode participar de várias empresas, com um papel em cada uma. Remover alguém da empresa desativa o vínculo; o usuário continua existindo.

**Empresa × autoria.** Em toda tabela de negócio, `account_id` é obrigatório, com chave estrangeira e índice. Quando importa saber quem fez a ação, a coluna de autoria tem nome explícito, é opcional e usa `ON DELETE SET NULL`:

| Tabela | Autoria |
| --- | --- |
| `supplier_imports`, `supplier_discovery_searches`, `privacy_requests`, `third_party_operators` | `created_by_id` |
| `audit_reviews` | `reviewed_by_id` |
| `privacy_audit_events` | `performed_by_id` (vazio em ações automáticas) |
| `account_invitations` | `invited_by_id`, `accepted_by_id` |
| `analytics_api_tokens` | `created_by_id`, `revoked_by_id` |

Retornos comerciais, revisões e registros LGPD também apontam para o lote e precisam estar na mesma empresa dele (validado no model e conferido por `tenancy:verify`).

`user_id` só existe onde representa a própria pessoa: `account_memberships` e `workspace_notification_reads` (leitura pessoal, com a empresa na chave). O teste `test/architecture/tenancy_schema_test.rb` impede que `user_id` volte a uma tabela de negócio.

## Empresa atual e autorização

- `current_account` e `current_membership` vêm só de `CurrentAccount`, a partir dos vínculos ativos. Com um vínculo, a empresa é escolhida sozinha; com mais de um, vale a escolha feita em "Trocar de empresa" (sessão).
- Toda consulta de tela parte de `current_account`. Um id de outra empresa responde 404.
- As permissões ficam em `AccountMembership#can_*`. Os controllers declaram o que exigem com `require_permission` (concern `MembershipAuthorization`).

| Permissão | admin | manager | operator | auditor | viewer |
| --- | :-: | :-: | :-: | :-: | :-: |
| Consultar lotes, resultados, Analytics, equipe | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ver evidências (`can_view_evidence?`) | ✓ | ✓ | ✓ | ✓ | |
| Iniciar validações (`can_start_validation?`) | ✓ | ✓ | ✓ | | |
| Importar e excluir lotes, buscar fornecedores (`can_import_data?`) | ✓ | ✓ | | | |
| Exportar dados por registro (`can_export_data?`) | ✓ | ✓ | | ✓ | |
| Empresa, integrações e LGPD (`can_manage_settings?`, `can_manage_lgpd?`) | ✓ | | | | |
| Equipe e tokens de BI (`can_manage_team?`, `can_manage_bi_tokens?`) | ✓ | | | | |
| Anonimizar evidências (`can_anonymize_evidence?`) | ✓ | | | | |

Regras fixas: ninguém muda o próprio papel nem remove a si mesmo, e a empresa nunca fica sem administrador ativo (validado no vínculo).

## Convites

- O token tem 256 bits aleatórios. Só o HMAC dele fica no banco, e ele vale por 7 dias e uma única vez. Reenviar troca o token.
- A página `/convites/:token` mostra empresa e papel:
  - quem não tem conta cria uma já dentro da empresa do convite;
  - quem tem conta entra e aceita, ganhando um vínculo a mais, sem criar outro usuário.
- Só o e-mail convidado aceita, e o token nunca leva a outra empresa.
- Sem SMTP em desenvolvimento, o link aparece uma vez na tela de Equipe.

## Trilha LGPD

Os eventos ficam na trilha da empresa (`privacy_audit_events`), com o autor em `performed_by_id` e os detalhes em `metadata`.

| Evento | Quando |
| --- | --- |
| `account_member_invited`, `_invitation_resent`, `_invitation_canceled` | Gestão de convites |
| `account_member_joined`, `_role_changed`, `_removed`, `_reactivated` | Gestão de membros |
| `analytics_exported` | XLSX ou CSV do Analytics, com tipo, filtros e período |
| `analytics_bi_token_created`, `analytics_bi_token_revoked` | Tokens de BI |
| `analytics_api_accessed` | Uma vez por extração da API (primeira página) |
| `supplier_import_deleted` | Exclusão de lote. A trilha e as solicitações do lote continuam (`ON DELETE SET NULL`) |

## Analytics e API de BI

- Toda leitura passa por `Analytics::Scope.new(account:, filters:)`. As queries (`RecordsQuery`, `AttemptsQuery`, `BatchesQuery`, `QualificationQuery`) recebem relações já escopadas.
- O cache é por empresa, e a chave traz a versão das fontes que cada seção lê.
- A API somente leitura fica em `/api/v1/analytics/{summary,records,calls,batches}`, com o header `Authorization: Bearer lpbi_...`.
  - O token define a empresa.
  - Os campos são os mesmos do CSV (`Analytics::RowPresenter`).
  - Datas vêm em UTC; a paginação é por cursor (até 500 itens por página), com limite de 120 requisições por minuto por token.
- O contrato completo está em "API para desenvolvedores → API de Analytics".

## Quando evoluir

**Tabelas de projeção (`validation_records`, `call_attempts`).** A v1 lê o JSONB `response_payload`. Num teste com cerca de 20 mil registros (mil lotes), as páginas sem cache levaram de 0,6 s a 1,5 s; com o cache por empresa, só a primeira visita depois de uma mudança paga esse custo. Migre para projeções quando acontecer um destes casos:

- p95 de uma página sem cache acima de 800 ms em produção;
- mais de 50 mil registros numa empresa;
- necessidade de filtrar ou ordenar por campo do registro com índice (ex.: CNPJ, resultado) na API de BI.

As queries isolam a origem dos dados: trocar o JSONB por projeções muda só essas classes, não as telas, exportações ou API.

**Exportação XLSX em fila (Solid Queue).** A v1 é síncrona, com limite de 50 mil linhas na aba Registros. Com 20 mil registros, o arquivo completo levou de 4 s a 10 s. Leve para fila quando:

- a geração passar de 15 s;
- algum cliente se aproximar do limite de 50 mil linhas;
- o servidor web começar a ter requisições longas concorrendo com as telas.

O CSV já é gerado em streaming e não tem esse limite.

## Integração com a API de validação

- Cada empresa tem um `platform_account` na API (`accounts.validation_account_id`, 1:1). A
  chave administrativa (`PLATFORM_ADMIN_API_KEY`) só cadastra empresas e provedores; lotes e
  consultas usam o token da própria empresa.
- **Resultado e evidência são separados na API.** A sincronização busca
  `GET /validations/:id/evidence` quando o progresso do lote muda e mescla tentativas,
  recusa e validade das evidências no `response_payload` por `external_id`
  (`SupplierImports::RemoteEvidenceMerger`). Lotes sincronizados antes disso:
  `bin/rails evidence:backfill` (lista) e `APPLY=1` (grava).
- **Iniciar lote é idempotente.** O início é reivindicado sob lock (2 min) e o `batch_id`
  enviado fica gravado; depois de timeout ou erro de rede o mesmo id é reenviado, e a API
  devolve o lote que já criou. Id novo só para refazer um lote que a API confirmou.
- A sincronização periódica trata cada lote como fronteira: erro inesperado em um não para
  os das outras empresas.
- Toda chamada à API leva `X-Request-ID` (id da requisição, ou `job-<id>` em jobs), o mesmo
  que aparece nos logs da API.
- Testes de contrato usam JSONs gerados pela própria API em
  `test/fixtures/files/validation_api/` (`scripts/export_contract_fixtures.py` em
  `api_confaith_ai`). Visão completa dos dois serviços: `api_confaith_ai/docs/architecture.md`.

## Verificação

- `bin/rails tenancy:verify` confere que todo dado de negócio tem empresa, que filhos de lote estão na empresa do lote e que toda empresa ativa tem admin.
- `test/architecture/tenancy_schema_test.rb` exige `account_id` em toda tabela fora de `TABLES_WITHOUT_ACCOUNT`, que lista o motivo de cada exceção (`plans`, `suppliers` e `supplier_import_versions` estão lá por não terem uso; são candidatas a remoção).
- `bin/rails finished_at:dry_run` mostra a situação de `finished_at`. `finished_at:apply` corrige só registros comprovados e grava antes/depois em `tmp/backups`; `finished_at:restore` desfaz.
