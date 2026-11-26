# Equipe da empresa atual: membros (ativos e desativados) e convites em aberto.
# Todos os membros veem quem faz parte da empresa; só quem pode gerenciar a equipe vê os
# convites e age sobre eles.
class TeamController < ApplicationController
  before_action :authenticate_user!

  def index
    @memberships = current_account.account_memberships.includes(:user)
      .order(Arel.sql("CASE account_memberships.status WHEN 'active' THEN 0 ELSE 1 END"), "users.name")
      .references(:users)
    @invitations = current_membership.can_manage_team? ? current_account.account_invitations.open.includes(:invited_by).order(created_at: :desc) : AccountInvitation.none
    @invitation_link = flash[:invitation_link] if Rails.env.local?
  end
end
