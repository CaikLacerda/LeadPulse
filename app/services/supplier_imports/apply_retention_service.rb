module SupplierImports
  class ApplyRetentionService
    def initialize(now: Time.current)
      @now = now
    end

    def call
      anonymized = 0

      SupplierImport.includes(:user).find_each do |supplier_import|
        next unless supplier_import.evidence_retention_expired?(@now)

        SupplierImports::AnonymizeEvidenceService.new(
          user: supplier_import.user,
          supplier_import: supplier_import
        ).call

        PrivacyAudit::Logger.log!(
          user: supplier_import.user,
          action: 'retention_evidence_anonymized',
          supplier_import: supplier_import,
          resource: supplier_import,
          metadata: {
            evidence_expires_at: supplier_import.evidence_expires_at&.iso8601,
            retention_days: supplier_import.privacy_notice['evidence_retention_days']
          }
        )
        anonymized += 1
      rescue ValidationApi::Error, ActiveRecord::ActiveRecordError => e
        Rails.logger.warn("Falha ao aplicar retenção LGPD no lote #{supplier_import.id}: #{e.message}")
      end

      anonymized
    end
  end
end
