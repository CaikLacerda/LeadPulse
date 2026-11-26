class DeveloperDocsController < ApplicationController
  before_action :authenticate_user!

  def show
    @api_base_url = ENV.fetch("VALIDATION_API_BASE_URL", "http://127.0.0.1:8000")
    @getting_started = [
      "Cadastre a empresa e gere o token dentro do LeadPulse.",
      "Guarde o bearer token com segurança no seu ERP, CRM ou backoffice.",
      "Padronize telefones no formato E.164, como +55DDDNÚMERO, antes de enviar o lote.",
      "Envie lotes cadastrais ou de fornecedor para a API.",
      "Consulte o processamento dos lotes pelo batch_id retornado.",
      "Consuma a busca de fornecedores e os resultados de validação direto do seu sistema."
    ]
    @auth_modes = [
      {
        title: "Autenticação da API",
        auth: "Authorization: Bearer tkn_live_...",
        description: "É a autenticação usada pelo sistema do cliente para enviar lotes, consultar status, buscar fornecedores e ler resultados."
      }
    ]
    @integration_types = [
      {
        title: "Validação cadastral",
        description: "Fluxo para confirmar telefone e atualizar registros de empresas já conhecidas."
      },
      {
        title: "Validação de fornecedor",
        description: "Fluxo por planilha para confirmar se o contato atende um segmento e se existe abertura comercial."
      },
      {
        title: "Busca de fornecedores",
        description: "Busca fornecedores na web, estrutura o resultado e devolve planilha sem disparar chamadas automaticamente."
      },
      {
        title: "Integração com ERP",
        description: "O ERP consome a API com bearer token emitido no SaaS, envia lotes e consulta resultados pelo batch_id."
      }
    ]
    @public_endpoint_groups = [
      {
        title: "Validação de lotes",
        description: "Endpoints que o ERP ou sistema externo chama para enviar e acompanhar lotes.",
        items: [
          {
            title: "Enviar lote de validação cadastral",
            method: "POST",
            path: "/validations",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Recebe um lote de empresas já conhecidas para validar telefone, status e resultado das tentativas.",
            request: <<~JSON.strip,
              {
                "batch_id": "erp_lote_20260328_001",
                "source": "integracao_externa",
                "records": [
                  {
                    "external_id": "1",
                    "client_name": "Fornecedor Alfa LTDA",
                    "cnpj": "11.222.333/0001-81",
                    "phone": "+5511999999999",
                    "email": "contato@fornecedor.com"
                  }
                ]
              }
            JSON
            response: <<~JSON.strip
              {
                "batch_id": "erp_lote_20260328_001",
                "status": "accepted",
                "message": "Lote de validação recebido com sucesso."
              }
            JSON
          },
          {
            title: "Consultar lote cadastral",
            method: "GET",
            path: "/validations/{batch_id}",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Retorna status do lote, resumo geral e detalhes de cada registro processado.",
            request: <<~TEXT.strip,
              batch_id=erp_lote_20260328_001
            TEXT
            response: <<~JSON.strip
              {
                "batch_id": "erp_lote_20260328_001",
                "batch_status": "processing",
                "result_ready": false,
                "records": [
                  {
                    "external_id": "1",
                    "final_status": "processing",
                    "phone_confirmed": null
                  }
                ]
              }
            JSON
          },
          {
            title: "Enviar lote de validação de fornecedor",
            method: "POST",
            path: "/supplier-validations",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Usa uma planilha de fornecedores já conhecida para validar segmento e abertura comercial por ligação.",
            request: <<~JSON.strip,
              {
                "batch_id": "supplier_batch_20260328_001",
                "source": "integracao_externa",
                "segment_name": "Adubo",
                "records": [
                  {
                    "external_id": "1",
                    "supplier_name": "Fornecedor Adubo 1 LTDA",
                    "phone": "+5511988887777"
                  }
                ]
              }
            JSON
            response: <<~JSON.strip
              {
                "batch_id": "supplier_batch_20260328_001",
                "status": "accepted",
                "message": "Lote de validação de fornecedores recebido com sucesso."
              }
            JSON
          },
          {
            title: "Consultar lote de fornecedor",
            method: "GET",
            path: "/supplier-validations/{batch_id}",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Devolve o lote processado com bloco extra de supplier_validation no response.",
            request: <<~TEXT.strip,
              batch_id=supplier_batch_20260328_001
            TEXT
            response: <<~JSON.strip
              {
                "batch_id": "supplier_batch_20260328_001",
                "batch_status": "completed",
                "records": [
                  {
                    "external_id": "1",
                    "final_status": "qualified_supplier",
                    "supplier_validation": {
                      "phone_belongs_to_company": true,
                      "supplies_segment": true,
                      "commercial_interest": true
                    }
                  }
                ]
              }
            JSON
          }
        ]
      },
      {
        title: "Busca de fornecedores",
        description: "Busca web estruturada para formar lotes de fornecedores.",
        items: [
          {
            title: "Buscar fornecedores na web",
            method: "POST",
            path: "/supplier-discovery",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Pesquisa fornecedores reais na web, estrutura o resultado e devolve um search_id com link para planilha.",
            request: <<~JSON.strip,
              {
                "segment_name": "Adubo",
                "region": "Campinas",
                "max_suppliers": 10,
                "include_locations": true
              }
            JSON
            response: <<~JSON.strip
              {
                "search_id": "supplier_search_20260328150000_ab12cd",
                "mode": "openai_web_search",
                "total_suppliers": 3,
                "suppliers": [
                  {
                    "supplier_name": "Agro Campinas",
                    "phone": "+5519999999999",
                    "city": "Campinas",
                    "state": "SP",
                    "address": "Campinas, SP",
                    "latitude": -22.9056,
                    "longitude": -47.0608,
                    "google_maps_url": "https://www.google.com/maps/search/?api=1&query=Agro%20Campinas%2C%20Campinas%2C%20SP"
                  }
                ],
                "downloadable_file_url": "/supplier-discovery/supplier_search_20260328150000_ab12cd/results.xlsx"
              }
            JSON
          },
          {
            title: "Consultar busca anterior",
            method: "GET",
            path: "/supplier-discovery/{search_id}",
            auth: "Authorization: Bearer tkn_live_...",
            description: "Recupera o resultado estruturado de uma busca anterior da mesma conta autenticada.",
            request: <<~TEXT.strip,
              search_id=supplier_search_20260328150000_ab12cd
            TEXT
            response: <<~JSON.strip
              {
                "search_id": "supplier_search_20260328150000_ab12cd",
                "segment_name": "Adubo",
                "suppliers": [
                  {
                    "supplier_name": "Fornecedor Exemplo LTDA",
                    "phone": "+5511999999999",
                    "website": "https://fornecedor.com.br",
                    "discovery_confidence": 0.82
                  }
                ]
              }
            JSON
          }
        ]
      },
      {
        id: "analytics-api",
        title: "API de Analytics (BI)",
        description: "Somente leitura, para Power BI, Tableau, Excel Power Query ou qualquer cliente HTTP. Use um token de BI criado em Integrações → Tokens de BI: ele identifica a empresa e não serve para a API de validação. Datas em UTC (ISO 8601), durações em segundos, códigos estáveis. Filtros: from e to (YYYY-MM-DD, até 366 dias; padrão: últimos 30), compare, workflow_kind, source, batch_id e, em batches, status. Paginação por cursor: page[size] até 500 e page[after] com o valor de meta.next_cursor (ou siga links.next). Limite de 120 requisições por minuto por token.",
        items: [
          {
            method: "GET",
            path: "/api/v1/analytics/summary",
            title: "Indicadores do período",
            auth: "Authorization: Bearer lpbi_...",
            description: "Indicadores com valor, amostra (sample) e período anterior. A variação (change) só vem quando é conclusiva; comparison_status explica quando não vem.",
            request: <<~TEXT.strip,
              GET /api/v1/analytics/summary?from=2026-08-01&to=2026-08-31&compare=previous_period
            TEXT
            response: <<~JSON.strip
              {
                "data": {
                  "metrics": {
                    "confirmation_rate": {
                      "value": 0.625, "unit": "ratio", "sample": 8, "low_sample": true,
                      "previous": { "value": 0.5, "sample": 6 },
                      "change": null, "change_unit": null, "comparison_status": "low_sample"
                    }
                  }
                },
                "meta": { "period": { "from": "2026-08-01", "to": "2026-08-31", "time_zone": "America/Sao_Paulo" }, "min_sample": 20 }
              }
            JSON
          },
          {
            method: "GET",
            path: "/api/v1/analytics/records",
            title: "Registros",
            auth: "Authorization: Bearer lpbi_...",
            description: "Um registro por item, dos lotes com validação iniciada no período. Mesmas colunas do CSV de registros.",
            request: <<~TEXT.strip,
              GET /api/v1/analytics/records?from=2026-08-01&to=2026-08-31&page[size]=500
            TEXT
            response: <<~JSON.strip
              {
                "data": [
                  { "batch_id": 68, "batch_code": "LD-068", "validation_started_at": "2026-08-15T16:51:59Z",
                    "record_external_id": "1", "call_result": "confirmed", "qualification_outcome": "qualified_supplier",
                    "attempts_count": 1, "answered_duration_seconds": 108 }
                ],
                "meta": { "page_size": 500, "next_cursor": "WyIyMDI2LTA4..." },
                "links": { "next": "https://.../api/v1/analytics/records?page%5Bafter%5D=WyIyMDI2LTA4..." }
              }
            JSON
          },
          {
            method: "GET",
            path: "/api/v1/analytics/calls",
            title: "Tentativas de chamada",
            auth: "Authorization: Bearer lpbi_...",
            description: "Uma tentativa por item, pelo horário da própria tentativa. Mesmas colunas do CSV de tentativas.",
            request: <<~TEXT.strip,
              GET /api/v1/analytics/calls?from=2026-08-01&to=2026-08-31
            TEXT
            response: <<~JSON.strip
              {
                "data": [
                  { "batch_code": "LD-068", "record_external_id": "1", "attempt_number": 1,
                    "started_at": "2026-08-15T16:51:59Z", "status": "answered", "result": "confirmed", "duration_seconds": 108 }
                ],
                "meta": { "page_size": 100, "next_cursor": null }
              }
            JSON
          },
          {
            method: "GET",
            path: "/api/v1/analytics/batches",
            title: "Lotes",
            auth: "Authorization: Bearer lpbi_...",
            description: "Um lote por item, dos lotes criados no período, com registros, confirmações e tempos de operação.",
            request: <<~TEXT.strip,
              GET /api/v1/analytics/batches?from=2026-08-01&to=2026-08-31&status=concluido

              Power Query (M):
              Json.Document(Web.Contents("https://leadpulse.exemplo/api/v1/analytics/batches",
                [Headers = [Authorization = "Bearer " & Token]]))
            TEXT
            response: <<~JSON.strip
              {
                "data": [
                  { "batch_id": 68, "batch_code": "LD-068", "status": "concluido", "records": 2,
                    "confirmed": 1, "confirmation_rate": 0.5, "processing_seconds": 134 }
                ],
                "meta": { "page_size": 100, "next_cursor": null }
              }
            JSON
          }
        ]
      }
    ]
  end
end
