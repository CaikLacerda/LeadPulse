# Token somente leitura da API de Analytics (Power BI, Tableau, Power Query...).
#
# Identifica a empresa: toda consulta feita com ele usa Analytics::Scope da empresa dona.
# O segredo aparece uma única vez, na criação; no banco ficam só o HMAC e o prefixo. Não
# serve para a API de validação, e o token da API de validação não serve aqui.
class AnalyticsApiToken < ApplicationRecord
  PREFIX = "lpbi_".freeze
  VISIBLE_PREFIX_LENGTH = 12
  ACTIVE_LIMIT = 20
  LAST_USED_PRECISION = 1.minute

  belongs_to :account
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :revoked_by, class_name: "User", optional: true

  scope :active, -> { where(revoked_at: nil) }

  validates :name, presence: true, length: { maximum: 80 }
  validates :token_digest, :token_prefix, presence: true
  validate :within_active_limit, on: :create

  attr_reader :token

  def self.digest(token)
    OpenSSL::HMAC.hexdigest("SHA256", digest_key, token.to_s)
  end

  def self.digest_key
    @digest_key ||= Rails.application.key_generator.generate_key("leadpulse/analytics_api_tokens", 32)
  end

  # Token ativo correspondente ao segredo recebido, ou nil.
  def self.authenticate(token)
    return if token.blank? || !token.start_with?(PREFIX)

    active.includes(:account).find_by(token_digest: digest(token))
  end

  def generate_secret
    @token = PREFIX + SecureRandom.base58(40)
    self.token_digest = self.class.digest(@token)
    self.token_prefix = @token.first(VISIBLE_PREFIX_LENGTH)
    @token
  end

  def active?
    revoked_at.nil?
  end

  def revoke!(by:)
    update!(revoked_at: Time.current, revoked_by: by)
  end

  # Grava o último uso com precisão de um minuto, para não escrever a cada requisição.
  def touch_last_used!(now: Time.current)
    return if last_used_at.present? && last_used_at > now - LAST_USED_PRECISION

    update_column(:last_used_at, now)
  end

  private

  def within_active_limit
    return if account.blank? || account.analytics_api_tokens.active.count < ACTIVE_LIMIT

    errors.add(:base, "A empresa já tem #{ACTIVE_LIMIT} tokens ativos. Revogue algum antes de criar outro.")
  end
end
