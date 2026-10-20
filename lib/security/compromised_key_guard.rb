require "digest"

module Security
  module CompromisedKeyGuard
    # Fingerprints only; never put the compromised key itself here.
    COMPROMISED_MASTER_KEY_SHA256 = "ee9528df3896a82d2154c4639fd83cf656c1cb271589be6edba9d114d4409af0".freeze # gitleaks:allow (public SHA-256 fingerprint only)

    def self.compromised?(value)
      !value.to_s.strip.empty? && Digest::SHA256.hexdigest(value.to_s.strip) == COMPROMISED_MASTER_KEY_SHA256
    end

    COMPROMISED_SECRET_KEY_BASE_SHA256 = "17ef0a15dee998189a2ff91158b2bffd2fc64b3467187a9e1a2445dd4c0b606e".freeze # gitleaks:allow

    def self.check_secret_key_base!(secret)
      if Digest::SHA256.hexdigest(secret.to_s) == COMPROMISED_SECRET_KEY_BASE_SHA256
        raise "Compromised secret_key_base: migrate encrypted tokens before rotation"
      end
    end

    def self.check!(key)
      raise "Compromised Rails master key: follow the approved migration runbook before deployment" if compromised?(key)
    end
  end
end
