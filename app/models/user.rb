class User < ApplicationRecord
  attr_accessor :validation_twilio_auth_token, :validation_openai_api_key

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  TOKEN_ENCRYPTION_SALT = "leadpulse-validation-api-token".freeze
  TOKEN_ENCRYPTION_PREFIX = "enc:v1:".freeze
  ROLES = {
    admin: "Administrador",
    manager: "Gestor",
    operator: "Operador",
    auditor: "Auditor",
    viewer: "Visualizador"
  }.freeze
  REALTIME_MODELS = [
    [ "GPT Realtime 2.1 Mini", "gpt-realtime-2.1-mini" ],
    [ "GPT Realtime 2.1", "gpt-realtime-2.1" ],
    [ "GPT Realtime 1.5", "gpt-realtime-1.5" ],
    [ "GPT Realtime", "gpt-realtime" ]
  ].freeze

  validates :name, presence: true, length: { maximum: 255 }

  has_many :supplier_imports, dependent: :destroy
  has_many :supplier_discovery_searches, dependent: :destroy
  has_many :commercial_opportunities, dependent: :destroy
  has_many :audit_reviews, dependent: :destroy
  has_many :privacy_requests, dependent: :destroy
  has_many :third_party_operators, dependent: :destroy
  has_many :privacy_audit_events, dependent: :destroy

  validates :role, inclusion: { in: ROLES.keys.map(&:to_s) }
  validates :validation_company_name, :validation_spoken_company_name,
    :validation_owner_name, length: { maximum: 255 }, allow_blank: true
  validates :validation_owner_email, :lgpd_controller_email,
    format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 320 }, allow_blank: true
  validates :validation_twilio_account_sid, length: { maximum: 64 }, allow_blank: true
  validates :validation_twilio_webhook_base_url,
    format: { with: /\Ahttps:\/\/[^\s]+\z/, message: "deve ser uma URL HTTPS válida" },
    length: { maximum: 500 },
    allow_blank: true
  validates :validation_openai_realtime_model,
    presence: true,
    length: { maximum: 120 },
    format: { with: /\Agpt-realtime(?:[-.][a-z0-9.]+)*\z/ }
  validates :validation_openai_realtime_voice, presence: true, length: { maximum: 60 }
  validates :validation_openai_realtime_output_speed,
    numericality: { greater_than_or_equal_to: 0.25, less_than_or_equal_to: 1.5 },
    allow_nil: true
  validates :validation_openai_style_instructions, length: { maximum: 4_000 }, allow_blank: true
  validates :lgpd_legal_basis, :lgpd_purpose, presence: true
  validates :lgpd_legal_basis, length: { maximum: 80 }
  validates :lgpd_purpose, length: { maximum: 160 }
  validates :lgpd_notice_script, length: { maximum: 2_000 }, allow_blank: true
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
      item.is_a?(Hash) ? item["phone_number"] || item[:phone_number] : item
    end.compact.join("\n")
  end

  def validation_api_token_value
    stored_value = validation_api_token.to_s
    return if stored_value.blank?

    encrypted_value = stored_value.delete_prefix(TOKEN_ENCRYPTION_PREFIX)
    self.class.validation_api_token_encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    return if stored_value.start_with?(TOKEN_ENCRYPTION_PREFIX)

    stored_value
  end

  def validation_api_token_configured?
    validation_api_token_value.present?
  end

  def validation_ready?
    validation_account_id.present? &&
      validation_twilio_configured? &&
      validation_openai_configured? &&
      validation_api_token_configured?
  end

  def validation_twilio_configured?
    validation_account_response.to_h.dig("twilio", "configured") == true
  end

  def validation_openai_configured?
    validation_account_response.to_h.dig("openai", "configured") == true
  end

  def role_label
    ROLES.fetch(role.to_s.to_sym, role.to_s.humanize)
  end

  def can_manage_lgpd?
    role == "admin"
  end

  def can_manage_settings?
    role == "admin"
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
    role == "admin"
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
    return "Token oculto por segurança. Gere um novo token caso precise copiar novamente." if validation_api_token_configured?

    "Nenhum token gerado ainda."
  end

  class << self
    def encrypt_validation_api_token(raw_token)
      return if raw_token.blank?

      TOKEN_ENCRYPTION_PREFIX + validation_api_token_encryptor.encrypt_and_sign(raw_token)
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
