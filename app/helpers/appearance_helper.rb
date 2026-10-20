module AppearanceHelper
  THEME_COOKIE = "lp_theme".freeze
  THEMES = {
    "light" => { label: "Claro", icon: "fa-sun" },
    "dark" => { label: "Escuro", icon: "fa-moon" },
    "system" => { label: "Sistema", icon: "fa-desktop" }
  }.freeze

  # Preferência salva no cookie; "system" segue o tema do sistema operacional.
  def workspace_theme
    THEMES.key?(cookies[THEME_COOKIE]) ? cookies[THEME_COOKIE] : "system"
  end

  # Valor de <html data-theme>. Fica ausente em "system" para que a media query decida.
  def html_theme_attribute
    workspace_theme unless workspace_theme == "system"
  end
end
