# Sessão individual do aplicativo. O segredo nunca é persistido; trocar a senha invalida a sessão.
class MobileSession < ApplicationRecord
  PREFIX = "lpm_".freeze
  LIFETIME = 30.days

  belongs_to :user
  belongs_to :account

  validates :token_digest, :password_fingerprint, :expires_at, presence: true
  attr_reader :token

  def self.digest(value)
    key = Rails.application.key_generator.generate_key("leadpulse/mobile_sessions", 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, value.to_s)
  end

  def self.issue!(user:, account:)
    session = new(user:, account:, expires_at: LIFETIME.from_now,
      password_fingerprint: digest(user.encrypted_password))
    session.generate_secret
    session.save!
    session
  end

  def self.authenticate(token)
    return unless token.is_a?(String) && token.start_with?(PREFIX) && token.bytesize <= 128

    session = includes(:user, :account).find_by(token_digest: digest(token))
    return unless session && session.expires_at > Time.current
    return unless ActiveSupport::SecurityUtils.secure_compare(session.password_fingerprint, digest(session.user.encrypted_password))

    session
  end

  def generate_secret
    @token = PREFIX + SecureRandom.base58(40)
    self.token_digest = self.class.digest(@token)
  end
end
