# Único ponto que resolve a empresa (Account) e o vínculo (AccountMembership) do usuário logado.
#
# Só vínculos ativos contam. Com um vínculo, a empresa é escolhida automaticamente; com mais
# de um, vale a escolha guardada na sessão (select_current_account!) e, sem escolha, o
# vínculo mais antigo. Quem consome current_account não precisa saber como ela foi escolhida.
module CurrentAccount
  extend ActiveSupport::Concern

  SESSION_KEY = :current_account_id

  included do
    helper_method :current_account, :current_membership, :available_memberships
  end

  private

  def current_membership
    return unless user_signed_in?
    return @current_membership if defined?(@current_membership)

    @current_membership = available_memberships.find { |membership| membership.account_id == session[SESSION_KEY] } ||
      available_memberships.first
    session[SESSION_KEY] = @current_membership&.account_id
    @current_membership
  end

  def current_account
    current_membership&.account
  end

  def available_memberships
    return AccountMembership.none unless user_signed_in?

    @available_memberships ||= current_user.account_memberships.active.includes(:account).order(:created_at, :id).to_a
  end

  # Troca de empresa: só para uma empresa em que o usuário tem vínculo ativo.
  def select_current_account!(account_id)
    membership = available_memberships.find { |candidate| candidate.account_id == account_id.to_i }
    return false unless membership

    session[SESSION_KEY] = membership.account_id
    remove_instance_variable(:@current_membership) if defined?(@current_membership)
    true
  end

  def require_current_account!
    return if current_account

    sign_out(current_user)
    redirect_to new_user_session_path, alert: "Seu usuário não está vinculado a nenhuma empresa. Fale com o administrador da conta."
  end
end
