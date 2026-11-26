# Autorização por vínculo: a decisão é sempre de current_membership (papel na empresa atual),
# nunca de um atributo global do usuário. Os controllers declaram o que exigem:
#
#   require_permission :can_manage_lgpd?, message: "...", only: :index
#
# Sem permissão: HTML volta para uma página segura com o aviso; JSON recebe 403.
module MembershipAuthorization
  extend ActiveSupport::Concern

  DEFAULT_MESSAGE = "Seu perfil não possui permissão para esta ação.".freeze

  class_methods do
    def require_permission(permission, message: DEFAULT_MESSAGE, fallback: :root_path, **options)
      before_action(**options) { authorize_membership!(permission, message: message, fallback: fallback) }
    end
  end

  private

  def authorize_membership!(permission, message: DEFAULT_MESSAGE, fallback: :root_path)
    return if current_membership&.public_send(permission)

    respond_to do |format|
      format.json { render json: { error: message }, status: :forbidden }
      format.any { redirect_to (fallback.is_a?(Symbol) ? send(fallback) : fallback), alert: message }
    end
  end
end
