class DeveloperDocsController < ApplicationController
  before_action :authenticate_user!

  def show
    @api_base_url = ENV.fetch('VALIDATION_API_BASE_URL', 'http://127.0.0.1:8000')
    @getting_started = [
      'Cadastre a empresa e gere o token dentro do LeadPulse.',
      'Guarde o bearer token com segurança no seu ERP, CRM ou backoffice.',
      'Envie lotes cadastrais ou de fornecedor para a API.',
      'Consulte o processamento dos lotes pelo batch_id retornado.',
      'Consuma supplier discovery e endpoints mobile direto do seu sistema.'
    ]
    @auth_modes = [
      {
        title: 'Autenticação da API',
        auth: 'Authorization: Bearer tkn_live_...',
        description: 'É a autenticação usada pelo sistema do cliente para enviar lotes, consultar status, buscar fornecedores e consumir os endpoints mobile.'
      }
    ]
    @integration_types = [
      {
        title: 'Validação cadastral',
        description: 'Fluxo para confirmar telefone e atualizar registros de empresas já conhecidas.'
      },
      {
        title: 'Validação de fornecedor',
        description: 'Fluxo por planilha para confirmar se o contato atende um segmento e se existe abertura comercial.'
      },
      {
        title: 'Supplier discovery',
        description: 'Busca fornecedores na web, estrutura o resultado e devolve planilha sem disparar chamadas automaticamente.'
      },
      {
        title: 'Mobile insights',
        description: 'Entrega dashboard e lista paginada de chamadas para apps mobile e painéis dedicados.'
      }
    ]
    @public_endpoint_groups = [
      {
        title: 'Validação de lotes',
        description: 'Endpoints que o ERP ou sistema externo chama para enviar e acompanhar lotes.',
        items: [
          {
            title: 'Enviar lote de validação cadastral',
            method: 'POST',
            path: '/validations',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Recebe um lote de empresas já conhecidas para validar telefone, status e resultado das tentativas.',
            request: <<~JSON.strip,
              {
                "batch_id": "erp_lote_20260328_001",
                "source": "integracao_externa",
                "records": [
                  {
                    "external_id": "1",
                    "client_name": "Fornecedor Alfa LTDA",
                    "cnpj": "11.222.333/0001-81",
                    "phone": "5511999999999",
                    "email": "contato@fornecedor.com"
                  }
                ]
              }
            JSON
            response: <<~JSON.strip
              {
                "batch_id": "erp_lote_20260328_001",
                "status": "accepted",
                "message": "Lote de validacao recebido com sucesso."
              }
            JSON
          },
          {
            title: 'Consultar lote cadastral',
            method: 'GET',
            path: '/validations/{batch_id}',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Retorna status do lote, resumo geral e detalhes de cada registro processado.',
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
            title: 'Enviar lote de validação de fornecedor',
            method: 'POST',
            path: '/supplier-validations',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Usa uma planilha de fornecedores já conhecida para validar segmento e abertura comercial por ligação.',
            request: <<~JSON.strip,
              {
                "batch_id": "supplier_batch_20260328_001",
                "source": "integracao_externa",
                "segment_name": "Adubo",
                "callback_phone": "5511999999999",
                "callback_contact_name": "Comercial Agro Compras",
                "records": [
                  {
                    "external_id": "1",
                    "supplier_name": "Fornecedor Adubo 1 LTDA",
                    "phone": "5511988887777"
                  }
                ]
              }
            JSON
            response: <<~JSON.strip
              {
                "batch_id": "supplier_batch_20260328_001",
                "status": "accepted",
                "message": "Lote de validacao de fornecedores recebido com sucesso."
              }
            JSON
          },
          {
            title: 'Consultar lote de fornecedor',
            method: 'GET',
            path: '/supplier-validations/{batch_id}',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Devolve o lote processado com bloco extra de supplier_validation no response.',
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
        title: 'Supplier discovery e mobile',
        description: 'Busca web estruturada e consumo de dados agregados para dashboards externos.',
        items: [
          {
            title: 'Buscar fornecedores na web',
            method: 'POST',
            path: '/supplier-discovery',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Pesquisa fornecedores reais na web, estrutura o resultado e devolve um search_id com link para planilha.',
            request: <<~JSON.strip,
              {
                "segment_name": "Adubo",
                "callback_phone": "5511999999999",
                "callback_contact_name": "Comercial Agro Compras",
                "region": "Campinas",
                "max_suppliers": 10
              }
            JSON
            response: <<~JSON.strip
              {
                "search_id": "supplier_search_20260328150000_ab12cd",
                "mode": "openai_web_search",
                "total_suppliers": 3,
                "downloadable_file_url": "/supplier-discovery/supplier_search_20260328150000_ab12cd/results.xlsx"
              }
            JSON
          },
          {
            title: 'Consultar busca anterior',
            method: 'GET',
            path: '/supplier-discovery/{search_id}',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Recupera o resultado estruturado de uma busca anterior da mesma conta autenticada.',
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
                    "phone": "5511999999999",
                    "website": "https://fornecedor.com.br",
                    "discovery_confidence": 0.82
                  }
                ]
              }
            JSON
          },
          {
            title: 'Dashboard mobile',
            method: 'GET',
            path: '/mobile/dashboard?period=24h|week|month',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Entrega agregados da conta autenticada para dashboards e apps mobile.',
            request: <<~TEXT.strip,
              period=week
            TEXT
            response: <<~JSON.strip
              {
                "period": "week",
                "summary": {
                  "total_batches": 4,
                  "validated_phones": 31,
                  "confirmed_numbers": 24,
                  "average_call_duration_seconds": 18.4
                }
              }
            JSON
          },
          {
            title: 'Lista paginada de chamadas',
            method: 'GET',
            path: '/mobile/calls?period=24h|week|month&limit=50&offset=0',
            auth: 'Authorization: Bearer tkn_live_...',
            description: 'Retorna as tentativas de chamada da conta autenticada com paginação e transcrição resumida.',
            request: <<~TEXT.strip,
              period=month
              limit=50
              offset=0
            TEXT
            response: <<~JSON.strip
              {
                "period": "month",
                "total": 3,
                "items": [
                  {
                    "external_id": "3",
                    "status": "not_answered",
                    "duration_seconds": 0,
                    "transcript_summary": "Ligacao nao atendida."
                  }
                ]
              }
            JSON
          }
        ]
      }
    ]
  end
end
