# Fase 3 do tenancy por conta: cada usuário existente vira uma empresa (Account) com um
# vínculo (AccountMembership) que preserva o papel atual. Só insere dados; `users` não muda.
#
# - Idempotente: usuários que já têm vínculo são ignorados.
# - Rastreável: accounts.legacy_user_id guarda o usuário de origem e permite um rollback exato.
# - Segredos: o token da API é copiado como texto criptografado, sem ser descriptografado.
# - Identidade remota: quem já tem conta na API recebe o external_account_id que a API conhece
#   ("leadpulse_user_<id>" era o fallback calculado em runtime).
class BackfillAccountsFromUsers < ActiveRecord::Migration[8.1]
  COPIED_COLUMNS = %w[
    validation_company_name validation_spoken_company_name validation_owner_name validation_owner_email
    validation_calling_profile validation_account_id validation_account_response
    validation_api_token validation_api_token_prefix validation_api_token_created_at
    validation_twilio_account_sid validation_twilio_phone_numbers validation_twilio_webhook_base_url
    validation_openai_realtime_model validation_openai_realtime_voice validation_openai_realtime_output_speed
    validation_openai_style_instructions
    lgpd_legal_basis lgpd_purpose lgpd_notice_script lgpd_evidence_retention_days lgpd_recording_allowed
    lgpd_stop_automatic_calls_on_refusal lgpd_controller_name lgpd_controller_email
  ].freeze
  VALID_ROLES = %w[admin manager operator auditor viewer].freeze

  def up
    add_column :accounts, :legacy_user_id, :bigint
    add_index :accounts, :legacy_user_id, unique: true, where: "legacy_user_id IS NOT NULL"

    columns = COPIED_COLUMNS.join(", ")
    source_columns = COPIED_COLUMNS.map { |column| "u.#{column}" }.join(", ")

    accounts_created = exec_update(<<~SQL.squish)
      INSERT INTO accounts (name, #{columns}, validation_external_account_id, legacy_user_id, created_at, updated_at)
      SELECT COALESCE(NULLIF(TRIM(u.validation_company_name), ''), u.name),
             #{source_columns},
             CASE
               WHEN NULLIF(TRIM(u.validation_external_account_id), '') IS NOT NULL THEN u.validation_external_account_id
               WHEN u.validation_account_id IS NOT NULL THEN 'leadpulse_user_' || u.id
             END,
             u.id, NOW(), NOW()
      FROM users u
      WHERE NOT EXISTS (SELECT 1 FROM account_memberships m WHERE m.user_id = u.id)
    SQL

    memberships_created = exec_update(<<~SQL.squish)
      INSERT INTO account_memberships (account_id, user_id, role, created_at, updated_at)
      SELECT a.id, u.id,
             CASE WHEN u.role IN (#{VALID_ROLES.map { |role| connection.quote(role) }.join(', ')}) THEN u.role ELSE 'viewer' END,
             NOW(), NOW()
      FROM accounts a
      JOIN users u ON u.id = a.legacy_user_id
      WHERE NOT EXISTS (SELECT 1 FROM account_memberships m WHERE m.account_id = a.id AND m.user_id = u.id)
    SQL

    say "Contas criadas: #{accounts_created}; vínculos criados: #{memberships_created}"

    users_without_membership = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM users u WHERE NOT EXISTS (SELECT 1 FROM account_memberships m WHERE m.user_id = u.id)
    SQL
    raise "Backfill incompleto: #{users_without_membership} usuário(s) sem conta." if users_without_membership.positive?
  end

  def down
    execute <<~SQL.squish
      DELETE FROM account_memberships
      WHERE account_id IN (SELECT id FROM accounts WHERE legacy_user_id IS NOT NULL)
    SQL
    execute "DELETE FROM accounts WHERE legacy_user_id IS NOT NULL"

    remove_index :accounts, :legacy_user_id
    remove_column :accounts, :legacy_user_id
  end
end
