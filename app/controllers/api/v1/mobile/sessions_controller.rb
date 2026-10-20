module Api
  module V1
    module Mobile
      class SessionsController < BaseController
        DUMMY_PASSWORD_DIGEST = Devise::Encryptor.digest(User, SecureRandom.hex(32)).freeze
        skip_before_action :authenticate_session!, only: :create
        rate_limit to: 10, within: 3.minutes, only: :create, by: -> { request.remote_ip },
          with: -> { rate_limited(180) }, store: RATE_LIMIT_STORE, scope: "mobile_login"

        def create
          email = params[:email].is_a?(String) ? params[:email].strip.downcase : ""
          password = params[:password].is_a?(String) ? params[:password] : ""
          user = User.find_for_authentication(email:)
          valid = user ? user.valid_password?(password) : Devise::Encryptor.compare(User, DUMMY_PASSWORD_DIGEST, password)
          return render_error("invalid_credentials", "E-mail ou senha inválidos.", :unauthorized) unless user && valid

          member = user.account_memberships.active.includes(:account).order(:created_at, :id).first
          return render_error("membership_inactive", "Seu usuário não possui acesso ativo a uma empresa.", :forbidden) unless member

          session = MobileSession.issue!(user:, account: member.account)
          render json: { token: session.token, expires_at: session.expires_at.utc.iso8601,
            user: { name: user.name, email: user.email }, account: { name: member.account.name },
            role: member.role, can_view_evidence: member.can_view_evidence? }, status: :created
        end

        def destroy
          mobile_session.destroy!
          head :no_content
        end
      end
    end
  end
end
