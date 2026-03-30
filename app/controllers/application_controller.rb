class ApplicationController < ActionController::Base
  APP_LOCALE = :"pt-BR"

  allow_browser versions: :modern
  stale_when_importmap_changes
  layout :layout_by_resource

  around_action :use_default_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end

  private

  def use_default_locale(&action)
    I18n.with_locale(APP_LOCALE, &action)
  end

  def layout_by_resource
    devise_controller? ? "devise" : "application"
  end
end
