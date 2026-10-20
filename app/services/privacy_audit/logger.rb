module PrivacyAudit
  class Logger
    # account: empresa dona do evento (a trilha LGPD é da empresa).
    # user: quem executou a ação; nil em ações automáticas do sistema.
    def self.log!(account:, user:, action:, supplier_import: nil, resource: nil, metadata: {})
      return if account.blank?

      PrivacyAuditEvent.create!(
        account: account,
        performed_by: user,
        supplier_import: supplier_import,
        action: action.to_s,
        resource_type: resource&.class&.name,
        resource_id: resource&.id&.to_s,
        metadata: metadata.compact,
        occurred_at: Time.current
      )
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("Falha ao registrar auditoria LGPD: #{e.message}")
      nil
    end
  end
end
