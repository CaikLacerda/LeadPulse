# Tokens de BI da empresa atual (Integrações → Tokens de BI). Só quem pode administrar
# tokens de BI vê e age. O segredo aparece uma vez, logo após a criação.
class AnalyticsApiTokensController < ApplicationController
  before_action :authenticate_user!
  require_permission :can_manage_bi_tokens?, message: "Seu perfil não pode administrar tokens de BI."

  def index
    @tokens = current_account.analytics_api_tokens.includes(:created_by, :revoked_by).order(Arel.sql("revoked_at IS NOT NULL"), created_at: :desc)
    @new_token = AnalyticsApiToken.new
    @created_secret = flash[:analytics_api_token]
  end

  def create
    token = current_account.analytics_api_tokens.new(name: params.require(:analytics_api_token)[:name], created_by: current_user)
    token.generate_secret

    if token.save
      log("analytics_bi_token_created", token)
      flash[:analytics_api_token] = token.token
      redirect_to analytics_api_tokens_path, notice: "Token \"#{token.name}\" criado. Copie agora: ele não será exibido de novo."
    else
      redirect_to analytics_api_tokens_path, alert: "Token não criado: #{token.errors.full_messages.to_sentence}."
    end
  end

  def destroy
    token = current_account.analytics_api_tokens.find(params[:id])
    return redirect_to(analytics_api_tokens_path, alert: "Este token já está revogado.") unless token.active?

    token.revoke!(by: current_user)
    log("analytics_bi_token_revoked", token)
    redirect_to analytics_api_tokens_path, notice: "Token \"#{token.name}\" revogado. Integrações que o usam deixam de funcionar."
  end

  private

  def log(action, token)
    PrivacyAudit::Logger.log!(account: current_account, user: current_user, action: action, resource: token,
      metadata: { name: token.name, token_prefix: token.token_prefix })
  end
end
