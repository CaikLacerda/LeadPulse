# Convites da empresa atual. O link com o token só existe no momento do envio: vai por
# e-mail e, em desenvolvimento, aparece uma vez na tela para ser copiado.
class TeamInvitationsController < ApplicationController
  before_action :authenticate_user!
  require_permission :can_manage_team?, fallback: :team_path, message: "Seu perfil não pode gerenciar a equipe."
  before_action :set_invitation, only: %i[resend destroy]

  def create
    result = team.invite(email: invitation_params[:email], role: invitation_params[:role])
    return redirect_to(team_path, alert: "Convite não criado: #{result.error}.") unless result.success?

    after_send(result, "Convite enviado para #{result.record.email}.")
  end

  def resend
    result = team.resend(@invitation)
    return redirect_to(team_path, alert: result.error) unless result.success?

    after_send(result, "Convite reenviado para #{@invitation.email}. O link anterior deixou de valer.")
  end

  def destroy
    result = team.cancel(@invitation)
    redirect_to team_path, **(result.success? ? { notice: "Convite para #{@invitation.email} cancelado." } : { alert: result.error })
  end

  private

  def set_invitation
    @invitation = current_account.account_invitations.find(params[:id])
  end

  def invitation_params
    params.require(:account_invitation).permit(:email, :role)
  end

  def team
    Accounts::TeamManagement.new(account: current_account, actor: current_user)
  end

  def after_send(result, notice)
    flash[:invitation_link] = invitation_url(result.token) if Rails.env.local?
    notice += " O e-mail não pôde ser enviado; copie o link abaixo." if !result.delivered && Rails.env.local?
    redirect_to team_path, notice: notice
  end
end
