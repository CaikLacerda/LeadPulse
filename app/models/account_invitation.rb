# Convite para uma pessoa entrar numa empresa com um papel.
#
# O token é aleatório (256 bits), vale por TTL, serve uma única vez e só existe em memória no
# momento em que é gerado; no banco fica apenas o HMAC dele. Um token só leva à empresa do
# próprio convite, e só a pessoa com o e-mail convidado pode aceitá-lo.
class AccountInvitation < ApplicationRecord
  TTL = 7.days
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  belongs_to :account
  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :accepted_by, class_name: "User", optional: true

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  scope :open, -> { where(accepted_at: nil, canceled_at: nil) }
  scope :pending, -> { open.where(expires_at: Time.current..) }

  validates :email, presence: true, format: { with: EMAIL_FORMAT }, length: { maximum: 255 }
  validates :role, inclusion: { in: AccountMembership::ROLES.keys }
  validates :token_digest, :expires_at, :sent_at, presence: true
  validate :email_not_already_active_member, on: :create

  attr_reader :token

  def self.digest(token)
    OpenSSL::HMAC.hexdigest("SHA256", digest_key, token.to_s)
  end

  def self.find_by_token(token)
    return if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.digest_key
    @digest_key ||= Rails.application.key_generator.generate_key("leadpulse/account_invitations", 32)
  end

  # Gera um token novo (o anterior deixa de valer) e renova a validade.
  def regenerate_token(now: Time.current)
    @token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@token)
    self.sent_at = now
    self.expires_at = now + TTL
    @token
  end

  def status
    return :accepted if accepted_at.present?
    return :canceled if canceled_at.present?
    return :expired if expires_at <= Time.current

    :pending
  end

  def pending?
    status == :pending
  end

  def role_label
    AccountMembership::ROLES.fetch(role.to_s, role.to_s.humanize)
  end

  def for_email?(email)
    self.email == email.to_s.strip.downcase
  end

  private

  def email_not_already_active_member
    return if account.blank? || email.blank?
    return unless account.account_memberships.active.joins(:user).where("lower(users.email) = ?", email).exists?

    errors.add(:email, "já faz parte da empresa")
  end
end
