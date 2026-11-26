# Fase 4 do tenancy final: credenciais, dados da empresa, política LGPD e papel saem de
# users. Tudo foi copiado para accounts/account_memberships (valores conferidos 1 a 1
# antes da remoção) e nenhuma parte da aplicação lê essas colunas em User.
# O down recria as colunas vazias; os valores antigos ficam no backup de tmp/backups.
class RemoveCompanyColumnsFromUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.remove :role, type: :string, default: "admin", null: false

      t.remove :validation_api_token, type: :text
      t.remove :validation_api_token_prefix, type: :string
      t.remove :validation_api_token_created_at, type: :datetime
      t.remove :validation_account_id, type: :bigint
      t.remove :validation_external_account_id, type: :string
      t.remove :validation_account_response, type: :jsonb, default: {}, null: false
      t.remove :validation_company_name, type: :string
      t.remove :validation_spoken_company_name, type: :string
      t.remove :validation_owner_name, type: :string
      t.remove :validation_owner_email, type: :string
      t.remove :validation_calling_profile, type: :text
      t.remove :validation_twilio_account_sid, type: :string
      t.remove :validation_twilio_phone_numbers, type: :jsonb, default: [], null: false
      t.remove :validation_twilio_webhook_base_url, type: :string
      t.remove :validation_openai_realtime_model, type: :string, default: "gpt-realtime-2.1-mini", null: false
      t.remove :validation_openai_realtime_voice, type: :string, default: "cedar", null: false
      t.remove :validation_openai_realtime_output_speed, type: :decimal, precision: 4, scale: 2
      t.remove :validation_openai_style_instructions, type: :text

      t.remove :lgpd_controller_name, type: :string
      t.remove :lgpd_controller_email, type: :string
      t.remove :lgpd_legal_basis, type: :string, default: "legitimate_interest", null: false
      t.remove :lgpd_purpose, type: :string, default: "qualificacao_de_fornecedores_por_chamada_automatizada", null: false
      t.remove :lgpd_evidence_retention_days, type: :integer, default: 180, null: false
      t.remove :lgpd_recording_allowed, type: :boolean, default: true, null: false
      t.remove :lgpd_stop_automatic_calls_on_refusal, type: :boolean, default: true, null: false
      t.remove :lgpd_notice_script, type: :text
    end
  end
end
