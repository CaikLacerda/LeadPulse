# Página pública do convite (/convites/:token). Quem ainda não entrou vê de qual empresa é o
# convite e escolhe entre entrar ou criar conta; o token fica na sessão para voltar aqui
# depois. Quem já entrou aceita com um clique, desde que seja o e-mail convidado.
class InvitationsController < ApplicationController
  SESSION_KEY = :invitation_token

  skip_before_action :require_current_account!
  before_action :set_invitation
  layout "auth"

  def show
    session[SESSION_KEY] = params[:token] if @invitation&.pending?
  end

  def accept
    return redirect_to(new_user_session_path) unless user_signed_in?
    return render(:show, status: :not_found) unless @invitation

    result = Accounts::AcceptInvitation.new(invitation: @invitation, user: current_user).call
    return redirect_to(invitation_path(params[:token]), alert: result.error) unless result.success?

    session.delete(SESSION_KEY)
    select_current_account!(result.membership.account_id)
    redirect_to root_path, notice: "Você entrou na equipe de #{result.membership.account.validation_company_name_value}."
  end

  private

  def set_invitation
    @invitation = AccountInvitation.includes(:account, :invited_by).find_by_token(params[:token])
  end
end
