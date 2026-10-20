class ApplicationController < ActionController::Base
  include CurrentAccount
  include MembershipAuthorization

  APP_LOCALE = :"pt-BR"

  allow_browser versions: :modern
  stale_when_importmap_changes
  layout :layout_by_resource

  around_action :use_default_locale
  before_action { Current.request_id = request.request_id }
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :require_current_account!, if: -> { user_signed_in? && !devise_controller? }

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
  end

  # Quem entrou a partir de um convite volta para a página do convite para aceitá-lo.
  def after_sign_in_path_for(resource)
    token = session[InvitationsController::SESSION_KEY]
    token.present? ? invitation_path(token) : super
  end

  private

  def use_default_locale(&action)
    I18n.with_locale(APP_LOCALE, &action)
  end

  # A edição da própria conta acontece dentro do workspace; as demais telas do Devise usam o visual da landing.
  def layout_by_resource
    return "application" unless devise_controller?
    return "application" if controller_name == "registrations" && action_name.in?(%w[edit update]) && user_signed_in?

    "auth"
  end
end
