# Papel e status dos membros da empresa atual. O vínculo é sempre buscado dentro de
# current_account: um id de outra empresa responde 404.
class TeamMembersController < ApplicationController
  before_action :authenticate_user!
  require_permission :can_manage_team?, fallback: :team_path, message: "Seu perfil não pode gerenciar a equipe."
  before_action :set_membership

  def update
    respond_with team.change_role(@membership, params.require(:account_membership)[:role]),
      notice: "Papel de #{@membership.user.name} alterado para #{@membership.role_label}."
  end

  def destroy
    respond_with team.remove(@membership), notice: "#{@membership.user.name} foi removido da empresa. O usuário continua existindo."
  end

  def reactivate
    respond_with team.reactivate(@membership), notice: "#{@membership.user.name} voltou a ter acesso à empresa."
  end

  private

  def set_membership
    @membership = current_account.account_memberships.includes(:user).find(params[:id])
  end

  def team
    Accounts::TeamManagement.new(account: current_account, actor: current_user)
  end

  def respond_with(result, notice:)
    if result.success?
      redirect_to team_path, notice: notice
    else
      redirect_to team_path, alert: result.error
    end
  end
end
