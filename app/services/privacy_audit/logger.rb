module PrivacyAudit
  class Logger
    def self.log!(user:, action:, supplier_import: nil, resource: nil, metadata: {})
      return if user.blank?

      PrivacyAuditEvent.create!(
        user: user,
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
