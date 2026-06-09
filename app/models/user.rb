class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  TOKEN_ENCRYPTION_SALT = 'leadpulse-validation-api-token'.freeze
  ROLES = {
    admin: 'Administrador',
    manager: 'Gestor',
    operator: 'Operador',
    auditor: 'Auditor',
    viewer: 'Visualizador'
  }.freeze

  validates :name, presence: true

  has_many :supplier_imports, dependent: :destroy
  has_many :supplier_discovery_searches, dependent: :destroy
  has_many :audit_reviews, dependent: :destroy
  has_many :privacy_requests, dependent: :destroy
  has_many :third_party_operators, dependent: :destroy
  has_many :privacy_audit_events, dependent: :destroy

  validates :role, inclusion: { in: ROLES.keys.map(&:to_s) }
  validates :lgpd_legal_basis, :lgpd_purpose, presence: true
  validates :lgpd_evidence_retention_days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 3650 }

  def validation_external_account_reference
    validation_external_account_id.presence || "leadpulse_user_#{id}"
  end

  def validation_company_name_value
    validation_company_name.presence || name
  end

  def validation_spoken_company_name_value
    validation_spoken_company_name.presence || validation_company_name_value
  end

  def validation_owner_name_value
    validation_owner_name.presence || name
  end

  def validation_owner_email_value
    validation_owner_email.presence || email
  end

  def validation_twilio_phone_numbers_text
    Array(validation_twilio_phone_numbers).map do |item|
      item.is_a?(Hash) ? item['phone_number'] || item[:phone_number] : item
    end.compact.join("\n")
  end

  def validation_api_token_value
    encrypted_value = validation_api_token.to_s
    return if encrypted_value.blank?

    self.class.validation_api_token_encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    encrypted_value
  end

  def validation_api_token_configured?
    validation_api_token_value.present? || validation_api_token_prefix.present?
  end

  def validation_ready?
    validation_account_id.present? &&
      validation_twilio_account_sid.present? &&
      validation_twilio_auth_token.present? &&
      validation_twilio_phone_numbers.present? &&
      validation_openai_api_key.present? &&
      validation_api_token_configured?
  end

  def role_label
    ROLES.fetch(role.to_s.to_sym, role.to_s.humanize)
  end

  def can_manage_lgpd?
    role == 'admin'
  end

  def can_import_data?
    %w[admin manager].include?(role)
  end

  def can_start_validation?
    %w[admin manager operator].include?(role)
  end

  def can_export_data?
    %w[admin manager auditor].include?(role)
  end

  def can_view_evidence?
    %w[admin manager operator auditor].include?(role)
  end

  def can_anonymize_evidence?
    role == 'admin'
  end

  def lgpd_notice_script_value
    lgpd_notice_script.presence || SupplierImports::PrivacyNoticePayload::NOTICE_SCRIPT
  end

  def persist_validation_api_token!(raw_token:, token_prefix:, created_at:)
    update!(
      validation_api_token: self.class.encrypt_validation_api_token(raw_token),
      validation_api_token_prefix: token_prefix,
      validation_api_token_created_at: created_at,
    )
  end

  def masked_validation_api_token
    return 'Token oculto por seguranca. Gere um novo token caso precise copiar novamente.' if validation_api_token_configured?

    'Nenhum token gerado ainda.'
  end

  class << self
    def encrypt_validation_api_token(raw_token)
      return if raw_token.blank?

      validation_api_token_encryptor.encrypt_and_sign(raw_token)
    end

    def validation_api_token_encryptor
      secret = Rails.application.secret_key_base
      key = ActiveSupport::KeyGenerator.new(secret).generate_key(
        TOKEN_ENCRYPTION_SALT,
        ActiveSupport::MessageEncryptor.key_len,
      )
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
