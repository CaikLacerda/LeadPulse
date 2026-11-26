module Accounts
  # Cadastro público: cada novo cadastro abre uma empresa e a pessoa entra como administradora.
  class ProvisionOwnerService
    def initialize(user:)
      @user = user
    end

    def call
      account = Account.create!(name: @user.name)
      account.account_memberships.create!(user: @user, role: "admin")
      account
    end
  end
end
