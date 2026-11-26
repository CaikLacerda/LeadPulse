module Accounts
  # Aceite de convite pela pessoa convidada. O convite precisa estar em aberto, dentro da
  # validade e ser do mesmo e-mail do usuário. Cria o vínculo (ou reativa um vínculo
  # desativado) na empresa do convite, e só nela; o convite deixa de valer.
  class AcceptInvitation
    Result = Data.define(:success, :membership, :error) do
      def success? = success
    end

    def initialize(invitation:, user:)
      @invitation = invitation
      @user = user
    end

    def call
      membership = nil
      error = nil

      AccountInvitation.transaction do
        @invitation.lock!
        error = refusal
        raise ActiveRecord::Rollback if error

        membership = @invitation.account.account_memberships.find_or_initialize_by(user: @user)
        if membership.persisted? && membership.active?
          error = "Você já faz parte desta empresa."
          raise ActiveRecord::Rollback
        end

        membership.assign_attributes(role: @invitation.role, status: AccountMembership::STATUS_ACTIVE, disabled_at: nil, invited_by: @invitation.invited_by)
        membership.save!
        @invitation.update!(accepted_at: Time.current, accepted_by: @user)
      end

      return Result.new(success: false, membership: nil, error: error) if error

      PrivacyAudit::Logger.log!(
        account: @invitation.account, user: @user, action: "account_member_joined",
        resource: membership, metadata: { role: membership.role, invitation_id: @invitation.id }
      )
      Result.new(success: true, membership: membership, error: nil)
    end

    private

    def refusal
      case @invitation.status
      when :accepted then "Este convite já foi usado."
      when :canceled then "Este convite foi cancelado."
      when :expired then "Este convite expirou. Peça um novo ao administrador da empresa."
      else
        "Este convite foi enviado para outro e-mail." unless @invitation.for_email?(@user.email)
      end
    end
  end
end
