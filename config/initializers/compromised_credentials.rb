require Rails.root.join("lib/security/compromised_key_guard")

# Fail closed at boot as well as in the deployment preflight. Never log key material.
if Rails.env.production?
  key_path = Rails.application.config.credentials.key_path
  key = ENV["RAILS_MASTER_KEY"].presence || (File.read(key_path).strip if File.file?(key_path))
  Security::CompromisedKeyGuard.check!(key)
  Security::CompromisedKeyGuard.check_secret_key_base!(Rails.application.secret_key_base)
end
