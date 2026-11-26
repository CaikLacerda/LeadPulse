ENV["RAILS_ENV"] ||= "test"
require_relative "../lib/testing/network_guard"
Testing::NetworkGuard.install!
require_relative "../config/environment"
require "rails/test_help"
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |file| require file }

# Tenancy nos testes: todo usuário pertence a uma empresa (Account) por um vínculo com papel.
module TenancyTestHelpers
  DEFAULT_PASSWORD = "Password123!".freeze

  # Cria usuário, empresa e vínculo. Atributos validation_* e lgpd_* vão para a empresa e
  # role vai para o vínculo, como na aplicação. Passe account: para colocar o usuário numa empresa existente.
  def create_member!(role: "admin", account: nil, **attributes)
    account_attributes = attributes.select { |key, _| key.to_s.start_with?("validation_", "lgpd_") }
    user_attributes = attributes.except(*account_attributes.keys)
    user_attributes[:password] ||= DEFAULT_PASSWORD
    user_attributes[:password_confirmation] ||= user_attributes[:password]

    user = User.create!(user_attributes)
    unless account
      account = Account.create!(name: "Empresa de #{user.name}")
      # Como no cadastro, toda empresa nasce com um administrador ativo.
      unless role == "admin"
        owner = User.create!(name: "Admin de #{user.name}", email: "admin-#{SecureRandom.hex(4)}@example.test", password: DEFAULT_PASSWORD, password_confirmation: DEFAULT_PASSWORD)
        AccountMembership.create!(account:, user: owner, role: "admin")
      end
    end
    account.update!(account_attributes) if account_attributes.any?
    AccountMembership.create!(account:, user:, role:)
    user
  end

  def account_of(user)
    user.accounts.order("account_memberships.created_at").first
  end

  def membership_of(user)
    user.account_memberships.order(:created_at).first
  end

  # Muda o papel de um membro. Se ele for o único admin, outro admin entra na empresa antes,
  # porque a empresa nunca fica sem administrador ativo.
  def change_role!(user, role)
    membership = membership_of(user)
    if role != "admin" && membership.last_active_admin?
      create_member!(name: "Admin reserva", email: "admin-reserva-#{SecureRandom.hex(4)}@example.test", account: membership.account, role: "admin")
    end
    membership.reload.update!(role: role)
  end
end

module ActiveSupport
  class TestCase
    setup { Rails.cache.clear }
    include TenancyTestHelpers
    include AnalyticsPayloadBuilder

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
