module SupplierImports
  module PrivacyNoticePayload
    module_function

    LEGAL_BASIS = 'legitimate_interest'.freeze
    RETENTION_DAYS = 180

    PURPOSES = {
      SupplierImport::WORKFLOW_KIND_CADASTRAL => 'validacao_cadastral_por_chamada_automatizada',
      SupplierImport::WORKFLOW_KIND_SUPPLIER => 'qualificacao_de_fornecedores_por_chamada_automatizada'
    }.freeze

    NOTICE_SCRIPT = (
      'Esta é uma chamada automatizada para validação cadastral e comercial. ' \
      'A ligação poderá ser gravada e transcrita para auditoria, ' \
      'e você pode pedir para interromper a qualquer momento.'
    ).freeze

    LEGAL_BASIS_OPTIONS = {
      'legitimate_interest' => 'Interesse legítimo',
      'contract_execution' => 'Execução de contrato',
      'consent' => 'Consentimento',
      'legal_obligation' => 'Obrigação legal/regulatória',
      'other' => 'Outro'
    }.freeze

    def build(workflow_kind:, user: nil, overrides: {})
      overrides = (overrides.presence || {}).to_h.deep_stringify_keys

      {
        legal_basis: overrides['legal_basis'].presence || user&.lgpd_legal_basis.presence || LEGAL_BASIS,
        purpose: overrides['purpose'].presence || user&.lgpd_purpose.presence || PURPOSES.fetch(workflow_kind, PURPOSES.fetch(SupplierImport::WORKFLOW_KIND_CADASTRAL)),
        notice_script: overrides['notice_script'].presence || user&.lgpd_notice_script_value.presence || NOTICE_SCRIPT,
        evidence_retention_days: retention_days(overrides['evidence_retention_days'] || user&.lgpd_evidence_retention_days),
        recording_allowed: boolean_value(overrides.fetch('recording_allowed', user&.lgpd_recording_allowed), default: true)
      }
    end

    def retention_days(value)
      days = value.to_i
      return RETENTION_DAYS if days <= 0

      [days, 3650].min
    end

    def boolean_value(value, default:)
      casted = ActiveModel::Type::Boolean.new.cast(value)
      casted.nil? ? default : casted
    end
  end
end
