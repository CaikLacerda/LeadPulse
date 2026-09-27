class ApplicationController < ActionController::Base
  APP_LOCALE = :"pt-BR"

  allow_browser versions: :modern
  stale_when_importmap_changes
  layout :layout_by_resource

  around_action :use_default_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
  end

  private

  def use_default_locale(&action)
    I18n.with_locale(APP_LOCALE, &action)
  end

  # A edição da própria conta acontece dentro do workspace; as demais telas do Devise usam o layout de autenticação.
  def layout_by_resource
    return "application" unless devise_controller?
    return "application" if controller_name == "registrations" && action_name.in?(%w[edit update]) && user_signed_in?

    "devise"
  end
end
