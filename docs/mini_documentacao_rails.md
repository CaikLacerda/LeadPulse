# Mini documentação do código Rails

## Visão geral

O Rails funciona como a camada web e orquestradora do produto.

Ele cuida de:

- autenticação do usuário com Devise
- configuração da conta operacional do cliente
- upload e gerenciamento de lotes
- abertura de buscas de fornecedores
- envio e consulta de lotes na API de validação
- auditoria e exportação de resultados

Em resumo: o Rails não executa a validação por voz. Ele monta payloads, chama a API externa, persiste o retorno e mostra isso na interface.

## Tabelas principais

### `users`

Guarda o usuário logado e também a configuração da conta dele na plataforma:

- dados básicos de login
- `validation_account_id`: id da conta remota na API
- `validation_company_name`, `validation_spoken_company_name`
- `validation_twilio_account_sid`, `validation_twilio_auth_token`, `validation_twilio_phone_numbers`
- `validation_openai_api_key`, modelo, voz e estilo do Realtime
- `validation_api_token`, `validation_api_token_prefix`

Papel na arquitetura:

- é a raiz da configuração operacional
- tudo que sai para a API externa depende do que está salvo aqui

### `supplier_imports`

É a tabela central do fluxo de validação.

Representa um lote que vai para validação, seja:

- cadastral
- segmento/fornecedor

Campos importantes:

- `workflow_kind`: tipo do lote
- `status`: status local no Rails (`pendente`, `processando`, `concluido`, `erro`)
- `remote_batch_id`: id do lote na API
- `request_payload`: payload enviado
- `response_payload`: payload retornado
- `result_ready`: se já existe resultado exportável
- `validation_started_at`, `last_synced_at`, `finished_at`
- `total_rows`, `valid_rows`, `invalid_rows`

Papel na arquitetura:

- é o “espelho local” do lote remoto
- concentra o estado do lote para a UI, auditoria e exportação

### `supplier_discovery_searches`

Guarda as buscas feitas na etapa de descoberta.

Campos importantes:

- `search_id`: id remoto da busca
- `segment_name`, `region`
- `callback_phone`, `callback_contact_name`
- `request_payload`, `response_payload`
- `results_xlsx_data`, `results_filename`
- `total_suppliers`, `generated_at`

Papel na arquitetura:

- registra a busca realizada
- armazena a planilha local gerada
- serve de origem para criar lote de segmento

### `supplier_import_versions`

Tabela auxiliar de histórico por lote.

Hoje é simples, com vínculo ao `supplier_import`, e pode ser usada como base para histórico/versionamento no futuro.

### `suppliers`

Tabela auxiliar com fornecedor vinculado ao lote.

Hoje ela aparece menos no fluxo principal que o `request_payload`/`response_payload`, mas ajuda como estrutura de domínio para fornecedor importado.

### `plans`

Tabela de plano/limite.

No estado atual do projeto, ela existe como apoio de domínio, mas não é o centro do fluxo operacional de validação.

## Models principais

### `User`

Arquivo: `app/models/user.rb`

Responsabilidades:

- autenticação com Devise
- relacionamento com lotes e buscas
- encapsular valores default da conta operacional
- descriptografar token da API
- dizer se a conta está pronta para operar com `validation_ready?`

Boa frase para apresentação:

> O `User` no nosso projeto não é só login. Ele também funciona como a configuração operacional daquela conta dentro da plataforma.

### `SupplierImport`

Arquivo: `app/models/supplier_import.rb`

Responsabilidades:

- representar um lote local
- diferenciar lote cadastral de lote de segmento
- expor helpers de status para a interface
- decidir se pode iniciar, sincronizar, exportar ou excluir

Boa frase para apresentação:

> O `SupplierImport` é a entidade principal da validação. Ele guarda tanto o pedido que saiu para a API quanto o retorno que voltou dela.

### `SupplierDiscoverySearch`

Arquivo: `app/models/supplier_discovery_search.rb`

Responsabilidades:

- representar uma busca salva
- fornecer os candidatos válidos para virar lote de segmento
- gerar nome e conteúdo de download

Boa frase para apresentação:

> A busca não é só consulta em tela. Ela vira um objeto persistido, com payload, retorno e planilha reaproveitável.

### `SupplierImportVersion`, `Supplier`, `Plan`

São modelos de apoio:

- `SupplierImportVersion`: histórico do lote
- `Supplier`: entidade auxiliar de fornecedor
- `Plan`: regra de plano/limite

## Controllers principais

### `PlatformSettingsController`

Arquivo: `app/controllers/platform_settings_controller.rb`

É o controller de configuração da conta.

Cuida de:

- empresa
- Twilio
- OpenAI
- token da API

Ele valida campos obrigatórios, chama a camada `ValidationApi::*` e persiste o snapshot local no `User`.

### `SupplierDiscoverySearchesController`

Arquivo: `app/controllers/supplier_discovery_searches_controller.rb`

Cuida do fluxo de busca:

- listar buscas
- abrir nova busca
- baixar resultado
- transformar busca em lote de segmento

Ele não faz a lógica pesada. Ele delega para services.

### `SupplierImportsController`

Arquivo: `app/controllers/supplier_imports_controller.rb`

É o controller central da operação de validação.

Cuida de:

- listagem de lotes
- upload/importação
- iniciar validação remota
- sincronizar status
- exportar resultado
- excluir lote

Boa frase para apresentação:

> O controller de lotes é fino. Ele recebe a ação da interface e encaminha para os services que concentram a regra de negócio.

### `ValidationAuditsController`

Arquivo: `app/controllers/validation_audits_controller.rb`

Monta a tela de auditoria a partir dos payloads já salvos no lote.

### `PagesController`

Arquivo: `app/controllers/pages_controller.rb`

Monta o dashboard da home logada:

- contadores
- lotes recentes
- buscas recentes
- flags de integração

## Services principais

## Camada de integração com API externa

### `ValidationApi::BaseClient`

Arquivo: `app/services/validation_api/base_client.rb`

É o cliente HTTP base.

Responsabilidades:

- GET/POST/PUT/download
- headers padrão
- bearer token do cliente
- admin key da plataforma
- tratamento de timeout e erro HTTP

### `ValidationApi::AuthenticatedService`

Arquivo: `app/services/validation_api/authenticated_service.rb`

Classe base dos services autenticados por token.

### `ValidationApi::PlatformAccountProvisioner`

Arquivo: `app/services/validation_api/platform_account_provisioner.rb`

Garante que o usuário tenha uma conta remota na API e persiste o snapshot dessa conta no `User`.

### Services específicos da API

Arquivos em:

- `app/services/validation_api/platform_accounts/*`
- `app/services/validation_api/supplier_discovery/*`
- `app/services/validation_api/validations/*`
- `app/services/validation_api/supplier_validations/*`

Padrão:

- um service por endpoint
- o controller chama o service
- o service usa `BaseClient` ou `AuthenticatedService`

## Camada de negócio local

### `SupplierImports::CreateFromUploadService`

Arquivo: `app/services/supplier_imports/create_from_upload_service.rb`

Fluxo:

- lê o arquivo enviado
- delega parsing para `PayloadParser`
- valida requisitos do tipo do lote
- gera `batch_id`
- monta `request_payload`
- cria o `SupplierImport` local como `pendente`

### `SupplierImports::StartRemoteValidationService`

Arquivo: `app/services/supplier_imports/start_remote_validation_service.rb`

Fluxo:

- valida se existe token da API
- normaliza o payload
- escolhe o endpoint remoto conforme o tipo do lote
- envia lote para a API
- atualiza status local e salva o retorno

É ele que conecta “cliquei em iniciar” com “o lote foi aceito pela API”.

### `SupplierImports::SyncRemoteStatusService`

Arquivo: `app/services/supplier_imports/sync_remote_status_service.rb`

Fluxo:

- consulta o lote remoto
- traduz o retorno remoto para status local
- salva `response_payload`, `finished_at`, `error_message` e `status`

### `SupplierImports::ExportResultCsvService`

Arquivo: `app/services/supplier_imports/export_result_csv_service.rb`

Responsável por:

- ler o `response_payload`
- montar colunas curadas
- traduzir labels
- gerar CSV final

É aqui que o retorno técnico vira planilha apresentável para operação.

### `SupplierImports::AuditEntriesService`

Arquivo: `app/services/supplier_imports/audit_entries_service.rb`

Lê o `response_payload` dos lotes e transforma isso em entradas de auditoria para a UI:

- horário
- ação
- resultado
- transcrição do cliente
- transcrição da IA

### `SupplierDiscoverySearches::CreateRemoteSearchService`

Arquivo: `app/services/supplier_discovery_searches/create_remote_search_service.rb`

Fluxo:

- monta payload da busca
- chama a API externa
- filtra fornecedores sem telefone
- persiste a busca local
- gera a planilha local para download

### `SupplierDiscoverySearches::CreateSupplierImportService`

Arquivo: `app/services/supplier_discovery_searches/create_supplier_import_service.rb`

Transforma uma busca salva em lote de validação de segmento.

## Fluxos principais para explicar na apresentação

## 1. Configuração da conta

Fluxo:

1. usuário entra em `Configurações`
2. `PlatformSettingsController` recebe os formulários
3. controller chama services `ValidationApi::PlatformAccounts::*`
4. `PlatformAccountProvisioner` persiste o snapshot local no `User`
5. o sistema passa a ter empresa, Twilio, OpenAI e token para operar

Resumo de fala:

> Primeiro eu configuro a conta operacional do usuário. Essa configuração fica no Rails e também é sincronizada com a API.

## 2. Busca de fornecedores

Fluxo:

1. usuário abre a tela `Busca`
2. `SupplierDiscoverySearchesController#create` chama `CreateRemoteSearchService`
3. service chama a API de busca
4. resultado volta, é filtrado localmente para remover itens sem telefone
5. Rails salva tudo em `supplier_discovery_searches`
6. o usuário pode baixar a planilha ou converter em lote de segmento

Resumo de fala:

> A busca vira um registro persistido, com payload, retorno e planilha pronta para reaproveitamento.

## 3. Importação de lote cadastral

Fluxo:

1. usuário envia uma planilha na tela `Validação`
2. `SupplierImportsController#create_import` chama `CreateFromUploadService`
3. o arquivo é parseado e validado
4. Rails cria um `SupplierImport` local com `request_payload`
5. status inicial fica `pendente`

Resumo de fala:

> Antes de falar com a API, o lote já nasce estruturado localmente, com request montada e rastreabilidade.

## 4. Importação de lote de segmento a partir da busca

Fluxo:

1. usuário clica em importar a partir de uma busca
2. `CreateSupplierImportService` pega os candidatos válidos
3. monta um lote `supplier_validation`
4. cria `SupplierImport` com origem `supplier_discovery`

Resumo de fala:

> O lote de segmento nasce da busca já filtrada, então ele reaproveita o que foi descoberto antes e evita retrabalho.

## 5. Início da validação remota

Fluxo:

1. usuário clica em `Iniciar`
2. `SupplierImportsController#start_validation`
3. `StartRemoteValidationService`
4. service escolhe o endpoint remoto:
   - `validations` para cadastral
   - `supplier_validations` para segmento
5. API aceita o lote
6. Rails salva `remote_batch_id`, `remote_batch_status`, `validation_started_at`

Resumo de fala:

> O Rails não executa a validação. Ele dispara a operação na API e passa a acompanhar o lote remoto.

## 6. Sincronização de status

Fluxo:

1. usuário clica em `Consultar status`
2. `SupplierImportsController#sync_status`
3. `SyncRemoteStatusService`
4. service consulta a API
5. Rails atualiza o lote local com o `response_payload`
6. a tela passa a refletir o estado novo

Resumo de fala:

> O lote local funciona como um espelho do lote remoto, para a UI não depender da API o tempo todo.

## 7. Auditoria

Fluxo:

1. `ValidationAuditsController#index`
2. chama `AuditEntriesService`
3. service lê `response_payload` dos lotes
4. monta entradas de auditoria com data, ação, resultado e transcrições

Resumo de fala:

> A auditoria é construída a partir do retorno já salvo no lote, sem depender de uma tabela separada de chamadas.

## 8. Exportação

Fluxo:

1. usuário clica em `Exportar`
2. `SupplierImportsController#export_result`
3. `ExportResultCsvService`
4. service transforma o payload técnico em CSV operacional

Resumo de fala:

> A exportação é a camada final de curadoria: ela transforma o retorno bruto da API em uma planilha que faz sentido para operação.

## Resumo arquitetural em uma frase

Se precisar resumir rápido na apresentação:

> O Rails é a camada de produto e orquestração. Ele autentica o usuário, salva a configuração da conta, monta lotes, chama a API de validação, persiste o retorno e transforma esse retorno em dashboard, auditoria e planilha.

## Arquivos para citar na apresentação

- `config/routes.rb`
- `app/models/user.rb`
- `app/models/supplier_import.rb`
- `app/models/supplier_discovery_search.rb`
- `app/controllers/platform_settings_controller.rb`
- `app/controllers/supplier_imports_controller.rb`
- `app/controllers/supplier_discovery_searches_controller.rb`
- `app/controllers/validation_audits_controller.rb`
- `app/services/validation_api/base_client.rb`
- `app/services/supplier_imports/create_from_upload_service.rb`
- `app/services/supplier_imports/start_remote_validation_service.rb`
- `app/services/supplier_imports/sync_remote_status_service.rb`
- `app/services/supplier_imports/export_result_csv_service.rb`
- `app/services/supplier_imports/audit_entries_service.rb`
- `app/services/supplier_discovery_searches/create_remote_search_service.rb`
- `app/services/supplier_discovery_searches/create_supplier_import_service.rb`
