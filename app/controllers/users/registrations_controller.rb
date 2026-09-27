module Users
  class RegistrationsController < Devise::RegistrationsController
    # Usuário e empresa nascem juntos: se a empresa não puder ser criada, o cadastro inteiro é desfeito.
    def create
      ActiveRecord::Base.transaction do
        super do |user|
          Accounts::ProvisionOwnerService.new(user:).call if user.persisted?
        end
      end
    end

    # Se a pessoa é o único membro, a empresa e os dados dela são excluídos junto (comportamento anterior).
    # Se a empresa tem outros membros, a exclusão é bloqueada para não apagar dados que também são deles.
    def destroy
      if current_account && current_account.account_memberships.active.where.not(user_id: resource.id).exists?
        redirect_to edit_user_registration_path,
          alert: "Sua empresa tem outros usuários. Peça a um administrador para remover seu acesso."
        return
      end

      ActiveRecord::Base.transaction do
        current_account&.destroy!
        super
      end
    end
  end
end
