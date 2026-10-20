module Maintenance
  # Run only in a maintenance window after a verified encrypted backup. No network I/O.
  # Secrets come from the operator's secret store, never from arguments in the shell.
  class ReencryptValidationTokens
    def initialize(old_secret:, new_secret:, apply: false)
      raise ArgumentError, "Both distinct keys are required" if old_secret.blank? || new_secret.blank? || old_secret == new_secret

      @old_encryptor = Account.validation_api_token_encryptor(secret: old_secret)
      @new_encryptor = Account.validation_api_token_encryptor(secret: new_secret)
      @apply = apply
    end

    def call
      count = 0
      Account.transaction do
        Account.where.not(validation_api_token: [ nil, "" ]).order(:id).lock.each do |account|
          stored = account.validation_api_token
          ciphertext = stored.delete_prefix(Account::TOKEN_ENCRYPTION_PREFIX)
          # A repeated run with the same new key must not corrupt or rewrite anything.
          next if decryptable?(@new_encryptor, ciphertext)

          raw = @old_encryptor.decrypt_and_verify(ciphertext)
          replacement = Account::TOKEN_ENCRYPTION_PREFIX + @new_encryptor.encrypt_and_sign(raw)
          raise "Encryption verification failed" unless @new_encryptor.decrypt_and_verify(replacement.delete_prefix(Account::TOKEN_ENCRYPTION_PREFIX)) == raw

          account.update_columns(validation_api_token: replacement) if @apply
          count += 1
        end
      end
      { candidates: count, changed: @apply ? count : 0 }
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
      raise "Token migration aborted; no changes committed. Investigate unreadable/legacy rows without logging token contents."
    end

    private

    def decryptable?(encryptor, ciphertext)
      encryptor.decrypt_and_verify(ciphertext).present?
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
      false
    end
  end
end
