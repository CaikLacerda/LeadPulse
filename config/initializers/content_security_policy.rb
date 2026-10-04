require Rails.root.join("lib/security/validation_websocket_origin")

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :self
    policy.form_action :self
    policy.script_src :self, "https://unpkg.com"
    policy.style_src :self, "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com", "https://unpkg.com"
    policy.font_src :self, "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"
    policy.img_src :self, :data, "https://images.unsplash.com", "https://tile.openstreetmap.org", "https://unpkg.com"
    policy.connect_src :self, Security::ValidationWebsocketOrigin.value
    policy.report_uri "/csp-reports"
  end
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(24) }
  config.content_security_policy_nonce_directives = %w[script-src]
  # Existing templates, ECharts and Leaflet use inline styles. Collect violations
  # before enforcement; do not hide them with unsafe-inline or unsafe-eval.
  config.content_security_policy_report_only = true
end
