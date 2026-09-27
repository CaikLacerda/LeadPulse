# Único ponto que resolve a empresa (Account) e o vínculo do usuário logado.
#
# Hoje cada usuário participa de uma empresa e ela é escolhida automaticamente. A escolha fica
# na sessão, o que já permite, no futuro, trocar de empresa sem mudar quem consome current_account.
module CurrentAccount
  extend ActiveSupport::Concern

  SESSION_KEY = :current_account_id

  included do
    helper_method :current_account, :current_membership
  end

  private

  def current_membership
    return unless user_signed_in?
    return @current_membership if defined?(@current_membership)

    memberships = current_user.account_memberships.includes(:account)
    @current_membership = memberships.find_by(account_id: session[SESSION_KEY]) ||
      memberships.order(:created_at, :id).first
    session[SESSION_KEY] = @current_membership&.account_id
    @current_membership
  end

  def current_account
    current_membership&.account
  end

  def require_current_account!
    return if current_account

    sign_out(current_user)
    redirect_to new_user_session_path, alert: "Seu usuário não está vinculado a nenhuma empresa. Fale com o administrador da conta."
  end
end
