module Accounts
  # Ações de gestão de equipe de uma empresa, feitas por um membro com can_manage_team?.
  #
  # Regras: ninguém muda o próprio papel nem remove a si mesmo; a empresa nunca fica sem
  # admin ativo (validado no vínculo); remover desativa o vínculo, sem apagar o usuário.
  # Toda ação entra na trilha LGPD da empresa.
  class TeamManagement
    Result = Data.define(:success, :record, :error, :token, :delivered) do
      def success? = success
    end

    def initialize(account:, actor:)
      @account = account
      @actor = actor
      @actor_membership = account.account_memberships.active.find_by(user: actor)
    end

    def invite(email:, role:)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?

      invitation = nil
      AccountInvitation.transaction do
        @account.account_invitations.open.where(email: email.to_s.strip.downcase).update_all(canceled_at: Time.current)
        invitation = @account.account_invitations.new(email: email, role: role, invited_by: @actor)
        invitation.regenerate_token
        invitation.save!
      end

      log("account_member_invited", invitation, email: invitation.email, role: invitation.role)
      delivered = deliver(invitation)
      Result.new(success: true, record: invitation, error: nil, token: invitation.token, delivered: delivered)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence, e.record)
    end

    def resend(invitation)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?
      return failure("Este convite já foi aceito ou cancelado.") unless invitation.accepted_at.nil? && invitation.canceled_at.nil?

      invitation.regenerate_token
      invitation.save!
      log("account_member_invitation_resent", invitation, email: invitation.email)
      delivered = deliver(invitation)
      Result.new(success: true, record: invitation, error: nil, token: invitation.token, delivered: delivered)
    end

    def cancel(invitation)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?
      return failure("Este convite já foi aceito ou cancelado.") unless invitation.accepted_at.nil? && invitation.canceled_at.nil?

      invitation.update!(canceled_at: Time.current)
      log("account_member_invitation_canceled", invitation, email: invitation.email)
      success(invitation)
    end

    def change_role(membership, role)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?
      return failure("Você não pode alterar o seu próprio papel.") if membership.user_id == @actor.id
      return failure("Papel inválido.") unless AccountMembership::ROLES.key?(role.to_s)

      previous = membership.role
      return success(membership) if previous == role.to_s
      return failure(membership.errors.full_messages.to_sentence, membership) unless membership.update(role: role)

      log("account_member_role_changed", membership, from: previous, to: membership.role)
      success(membership)
    end

    def remove(membership)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?
      return failure("Você não pode remover a si mesmo da empresa.") if membership.user_id == @actor.id
      return failure("Este membro já está desativado.") if membership.disabled?

      membership.status = AccountMembership::STATUS_DISABLED
      membership.disabled_at = Time.current
      return failure(membership.errors.full_messages.to_sentence, membership) unless membership.save

      log("account_member_removed", membership, role: membership.role)
      success(membership)
    end

    def reactivate(membership)
      return failure("Seu perfil não pode gerenciar a equipe.") unless allowed?
      return failure("Este membro já está ativo.") if membership.active?

      membership.reactivate!
      log("account_member_reactivated", membership, role: membership.role)
      success(membership)
    end

    private

    def allowed?
      @actor_membership&.can_manage_team?
    end

    def deliver(invitation)
      AccountInvitationMailer.invite(invitation, invitation.token).deliver_now
      true
    rescue StandardError => e
      Rails.logger.warn("[equipe] convite #{invitation.id} não enviado por e-mail: #{e.class}")
      false
    end

    def log(action, resource, metadata)
      PrivacyAudit::Logger.log!(account: @account, user: @actor, action: action, resource: resource, metadata: metadata)
    end

    def success(record)
      Result.new(success: true, record: record, error: nil, token: nil, delivered: nil)
    end

    def failure(message, record = nil)
      Result.new(success: false, record: record, error: message, token: nil, delivered: nil)
    end
  end
end
