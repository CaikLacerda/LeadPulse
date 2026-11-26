module Users
  class RegistrationsController < Devise::RegistrationsController
    # Link do convite traz o e-mail convidado já preenchido.
    def new
      build_resource(email: params[:email].to_s.strip.presence)
      yield resource if block_given?
      respond_with resource
    end

    # Quem se cadastra a partir de um convite entra na empresa do convite. Os demais criam a
    # própria empresa como admin. Se algo falhar, o cadastro inteiro é desfeito.
    def create
      ActiveRecord::Base.transaction do
        super do |user|
          next unless user.persisted?

          invitation = pending_invitation_for(user)
          if invitation
            result = Accounts::AcceptInvitation.new(invitation: invitation, user: user).call
            raise ActiveRecord::Rollback, result.error unless result.success?

            session.delete(InvitationsController::SESSION_KEY)
            session[CurrentAccount::SESSION_KEY] = result.membership.account_id
          else
            Accounts::ProvisionOwnerService.new(user: user).call
          end
        end
      end
    end

    # Exclusão da própria conta:
    # - empresa em que a pessoa é o único membro ativo é excluída junto com os dados;
    # - empresa com outros membros continua, sem o vínculo dela;
    # - o último admin de uma empresa com outros membros precisa promover alguém antes.
    def destroy
      memberships = resource.account_memberships.active.includes(:account).to_a
      shared = memberships.select { |membership| membership.account.account_memberships.active.where.not(user_id: resource.id).exists? }
      blocking = shared.select(&:last_active_admin?)
      if blocking.any?
        names = blocking.map { |membership| membership.account.validation_company_name_value }.to_sentence(last_word_connector: " e ", two_words_connector: " e ")
        redirect_to edit_user_registration_path,
          alert: "Você é o único administrador de #{names}. Promova outro membro a administrador antes de excluir sua conta."
        return
      end

      ActiveRecord::Base.transaction do
        (memberships - shared).each { |membership| membership.account.destroy! }
        super
      end
    end

    private

    def pending_invitation_for(user)
      invitation = AccountInvitation.find_by_token(session[InvitationsController::SESSION_KEY])
      invitation if invitation&.pending? && invitation.for_email?(user.email)
    end
  end
end
