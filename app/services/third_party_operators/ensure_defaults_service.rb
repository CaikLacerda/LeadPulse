module ThirdPartyOperators
  class EnsureDefaultsService
    DEFAULTS = [
      {
        name: 'Twilio',
        service_type: 'telephony',
        data_shared: 'Telefone do fornecedor, metadados da chamada, gravação e identificadores de telefonia.',
        purpose: 'Realizar chamadas automatizadas e disponibilizar evidências técnicas da ligação.',
        country: 'Fornecedor internacional',
        technical_owner: 'Responsável de integração'
      },
      {
        name: 'OpenAI',
        service_type: 'artificial_intelligence',
        data_shared: 'Áudio/transcrição e contexto mínimo da validação.',
        purpose: 'Conduzir conversa automatizada, transcrever respostas e apoiar classificação do resultado.',
        country: 'Fornecedor internacional',
        technical_owner: 'Responsável de IA'
      },
      {
        name: 'Google Maps',
        service_type: 'maps',
        data_shared: 'Nome/endereço do fornecedor e coordenadas de localização quando disponíveis.',
        purpose: 'Geocodificar fornecedores e abrir localização externa no Google Maps.',
        country: 'Fornecedor internacional',
        technical_owner: 'Responsável de produto'
      },
      {
        name: 'LeadPulse API',
        service_type: 'hosting',
        data_shared: 'Lotes de validação, status, transcrições, evidências e logs operacionais.',
        purpose: 'Processar validações, orquestrar integrações e armazenar resultados auditáveis.',
        country: 'Brasil/ambiente configurado',
        technical_owner: 'Equipe LeadPulse'
      }
    ].freeze

    def initialize(user:)
      @user = user
    end

    def call
      DEFAULTS.each do |attrs|
        @user.third_party_operators.find_or_create_by!(name: attrs[:name]) do |operator|
          operator.assign_attributes(attrs.merge(active: true))
        end
      end
    end
  end
end
